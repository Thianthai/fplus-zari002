CLASS zcl_zari002_processor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      ty_request TYPE zcl_zari002_http=>ty_request,
      ty_payment TYPE ztar_i002_pymt,
      ty_item    TYPE ztar_i002_item,
      tt_item    TYPE STANDARD TABLE OF ztar_i002_item WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_error,
        msgno              TYPE symsgno,
        msgtx              TYPE string,
        salesforce_id      TYPE ztar_i002_pymt-salesforce_id,
        salesforce_item_id TYPE ztar_i002_item-salesforce_item_id,
        field              TYPE string,
      END OF ty_error,
      tt_error TYPE STANDARD TABLE OF ty_error WITH EMPTY KEY,

      BEGIN OF ty_result,
        success    TYPE abap_bool,
        request_id TYPE ztar_i002_pymt-request_id,
        status     TYPE string,
        accepted   TYPE i,
        rejected   TYPE i,
        errors     TYPE tt_error,
      END OF ty_result.

    "! ฉีด dependency ได้เพื่อให้ unit test ไม่แตะ master data จริงและไม่ยิง HTTP
    METHODS constructor
      IMPORTING io_master_data TYPE REF TO zif_zari002_master_data OPTIONAL
                io_notify      TYPE REF TO zcl_zari003_sfdc_notify OPTIONAL.

    "! flow เดียวจบ: parse → normalize → validate → save → callback
    METHODS process
      IMPORTING iv_body          TYPE string
      RETURNING VALUE(rs_result) TYPE ty_result.

  PRIVATE SECTION.

    DATA go_master_data TYPE REF TO zif_zari002_master_data.
    DATA go_notify      TYPE REF TO zcl_zari003_sfdc_notify.

    METHODS normalize
      IMPORTING iv_request_id TYPE ztar_i002_pymt-request_id
      CHANGING  cs_payment    TYPE ztar_i002_pymt
                ct_item       TYPE tt_item
                cs_result     TYPE ty_result.

    METHODS validate
      IMPORTING is_payment      TYPE ztar_i002_pymt
                it_item         TYPE tt_item
      RETURNING VALUE(rt_error) TYPE tt_error.

    METHODS check_master_data
      IMPORTING is_payment      TYPE ztar_i002_pymt
                it_item         TYPE tt_item
      RETURNING VALUE(rt_error) TYPE tt_error.

    METHODS check_duplicate
      IMPORTING is_payment       TYPE ztar_i002_pymt
                it_item          TYPE tt_item
      RETURNING VALUE(rt_error) TYPE tt_error.

    METHODS save
      IMPORTING is_payment       TYPE ztar_i002_pymt
                it_item          TYPE tt_item
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS send_callback
      IMPORTING is_payment TYPE ztar_i002_pymt
                it_item    TYPE tt_item
                it_error   TYPE tt_error.

    "! แปลง finding ของ validator เป็น error ที่พร้อมส่งกลับ (ชื่อ field เป็น JSON แล้ว)
    METHODS to_errors
      IMPORTING it_finding            TYPE zcl_zari002_validator=>tt_finding
                iv_salesforce_id      TYPE ztar_i002_pymt-salesforce_id      OPTIONAL
                iv_salesforce_item_id TYPE ztar_i002_item-salesforce_item_id OPTIONAL
      RETURNING VALUE(rt_error)       TYPE tt_error.

    METHODS message_text
      IMPORTING iv_msgno         TYPE symsgno
                iv_v1            TYPE string OPTIONAL
                iv_v2            TYPE string OPTIONAL
                iv_v3            TYPE string OPTIONAL
                iv_v4            TYPE string OPTIONAL
      RETURNING VALUE(rv_result) TYPE string.

ENDCLASS.



CLASS zcl_zari002_processor IMPLEMENTATION.

  METHOD constructor.

    go_master_data = COND #( WHEN io_master_data IS BOUND THEN io_master_data
                             ELSE NEW zcl_zari002_master_data( ) ).

    go_notify = COND #( WHEN io_notify IS BOUND THEN io_notify
                        ELSE NEW zcl_zari003_sfdc_notify( ) ).

  ENDMETHOD.


  METHOD process.

    " 1. Parse ---------------------------------------------------------
    DATA ls_request TYPE ty_request.
    DATA ls_payment TYPE ty_payment.
    DATA lt_item    TYPE tt_item.

    TRY.
        zcl_zari002_json=>parse_json_request( EXPORTING iv_body    = iv_body
                                              IMPORTING es_request = ls_request ).
      CATCH zcx_zari002_error.
        rs_result-success = abap_false.
        APPEND VALUE #( msgno = '012'
                        msgtx = message_text( '012' )
                      ) TO rs_result-errors.
        RETURN.
    ENDTRY.

    " 2. Request ID ----------------------------------------------------
    IF ls_request-request_id IS INITIAL.
      ls_request-request_id = |{ cl_abap_context_info=>get_system_date( ) }_| &&
                              |{ cl_abap_context_info=>get_system_time( ) }|.
    ENDIF.

    rs_result-request_id = ls_request-request_id.

    " 3. Process -------------------------------------------------------
    LOOP AT ls_request-payments ASSIGNING FIELD-SYMBOL(<lfs_payment>).

      CLEAR: ls_payment, lt_item[].
      MOVE-CORRESPONDING <lfs_payment>       TO ls_payment.
      MOVE-CORRESPONDING <lfs_payment>-items TO lt_item.

      " 3.1 Normalize --------------------------------------------------
      normalize( EXPORTING iv_request_id = CONV #( ls_request-request_id )
                 CHANGING  cs_payment    = ls_payment
                           ct_item       = lt_item
                           cs_result     = rs_result ).

      " 3.2 Validate ---------------------------------------------------
      DATA(lt_error) = validate( is_payment = ls_payment
                                 it_item    = lt_item ).

      " 3.3 Save -------------------------------------------------------
      IF lt_error IS INITIAL.
        IF save( is_payment = ls_payment
                 it_item    = lt_item ) = abap_false.

          APPEND VALUE #( msgno         = '000'
                          msgtx         = message_text( iv_msgno = '000'
                                                        iv_v1    = `Database insert failed` )
                          salesforce_id = ls_payment-salesforce_id
                        ) TO lt_error.
        ENDIF.
      ENDIF.

      IF lt_error IS INITIAL.
        rs_result-accepted = rs_result-accepted + 1.
      ELSE.
        rs_result-rejected = rs_result-rejected + 1.
        APPEND LINES OF lt_error TO rs_result-errors.
      ENDIF.

      " 3.4 Callback ---------------------------------------------------
      send_callback( is_payment = ls_payment
                     it_item    = lt_item
                     it_error   = lt_error ).

    ENDLOOP.

    rs_result-success = xsdbool( rs_result-rejected = 0 ).

    IF rs_result-rejected = 0.
      rs_result-status = message_text( iv_msgno = '000'
                                       iv_v1    = `Success` ).
    ELSE.
      rs_result-status = message_text( iv_msgno = '000'
                                       iv_v1    = `Error` ).
    ENDIF.

  ENDMETHOD.


  METHOD normalize.

    DATA lt_company_code TYPE zif_zari002_master_data=>tt_company_code.

    " 1. Payment -------------------------------------------------------
    " Payment UUID
    TRY.
        cs_payment-payment_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lo_uuid_error).
        cs_result-success = abap_false.
        APPEND VALUE #( msgno = '000'
                        msgtx = lo_uuid_error->get_longtext( )
                      ) TO cs_result-errors.
        RETURN.
    ENDTRY.

    " Request ID
    cs_payment-request_id = iv_request_id.

    " G/L Account
    cs_payment-gl_account = zcl_zari002_validator=>to_internal_key( cs_payment-gl_account ).

    " Payment Method
    cs_payment-sap_payment_method = zcl_zari002_validator=>convert_payment_method( cs_payment-payment_method ).

    " Status
    cs_payment-status = 'N'. "New

    " Currency
    IF cs_payment-company_code IS NOT INITIAL.
      INSERT cs_payment-company_code INTO TABLE lt_company_code.
    ENDIF.

    DATA(lt_cc_info) = go_master_data->get_company_codes( lt_company_code ).
    cs_payment-currency = VALUE #( lt_cc_info[ company_code = cs_payment-company_code ]-currency OPTIONAL ).

    " Administrative Data
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD DATA(lv_now).

    cs_payment-created_by            = lv_user.
    cs_payment-created_at            = lv_now.
    cs_payment-last_changed_by       = lv_user.
    cs_payment-last_changed_at       = lv_now.
    cs_payment-local_last_changed_at = lv_now.

    " 2. Item ----------------------------------------------------------
    LOOP AT ct_item ASSIGNING FIELD-SYMBOL(<lfs_item>).

      " Item UUID
      TRY.
          <lfs_item>-item_uuid = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error INTO lo_uuid_error.
          cs_result-success = abap_false.
          APPEND VALUE #( msgno = '000'
                          msgtx = lo_uuid_error->get_longtext( )
                        ) TO cs_result-errors.
          RETURN.
      ENDTRY.

      " Payment UUID
      <lfs_item>-payment_uuid = cs_payment-payment_uuid.

      " Currency
      <lfs_item>-currency = cs_payment-currency.

      " Customer Code
      <lfs_item>-customer_code = zcl_zari002_validator=>to_internal_key( <lfs_item>-customer_code ).

      " Administrative Data
      <lfs_item>-created_by            = cs_payment-created_by.
      <lfs_item>-created_at            = cs_payment-created_at.
      <lfs_item>-last_changed_by       = cs_payment-last_changed_by.
      <lfs_item>-local_last_changed_at = cs_payment-local_last_changed_at.
    ENDLOOP.

  ENDMETHOD.


  METHOD validate.

    " 1. Validate Header -----------------------------------------------
    APPEND LINES OF to_errors( zcl_zari002_validator=>check_payment_mandatory( is_payment )
                             ) TO rt_error.

    APPEND LINES OF to_errors( zcl_zari002_validator=>check_dates( is_payment )
                             ) TO rt_error.

    APPEND LINES OF to_errors( zcl_zari002_validator=>check_cheque_fields( is_payment )
                             ) TO rt_error.

    APPEND LINES OF to_errors( zcl_zari002_validator=>check_number_of_items(
                                 iv_number_of_items = is_payment-number_of_items_in_payment
                                 iv_item_count      = lines( it_item ) )
                             ) TO rt_error.

    APPEND LINES OF to_errors( zcl_zari002_validator=>check_amount_paid_total(
                                 iv_salesforce_id = is_payment-salesforce_id
                                 it_item          = it_item )
                             ) TO rt_error.

    APPEND LINES OF to_errors( zcl_zari002_validator=>check_item_ids( it_item )
                             ) TO rt_error.

    " 2. Validate Item -------------------------------------------------
    LOOP AT it_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
      APPEND LINES OF to_errors( it_finding            = zcl_zari002_validator=>check_item_mandatory( <lfs_item> )
                                 iv_salesforce_id      = is_payment-salesforce_id
                                 iv_salesforce_item_id = <lfs_item>-salesforce_item_id
                               ) TO rt_error.
    ENDLOOP.

    " 3. Validate Master Data ------------------------------------------
    APPEND LINES OF check_master_data( is_payment = is_payment
                                       it_item    = it_item
                                     ) TO rt_error.

    " 4. Validate Duplicate --------------------------------------------
    APPEND LINES OF check_duplicate( is_payment = is_payment
                                     it_item    = it_item
                                   ) TO rt_error.

*   ---- ที่ว่างรอคำตอบ ----
*   check_amount_format       → 009 (OQ-10)
*   check_payment_total       → 007 (OQ-05)
*   check_cheque_bank_branch  → 008 (OQ-01)
*   check_ar_open_item        → 206 (OQ-08)

  ENDMETHOD.


  METHOD check_master_data.

    DATA lt_company_code TYPE zif_zari002_master_data=>tt_company_code.
    DATA lt_gl_key       TYPE zif_zari002_master_data=>tt_gl_key.
    DATA lt_pm_key       TYPE zif_zari002_master_data=>tt_payment_method_key.
    DATA lt_customer     TYPE zif_zari002_master_data=>tt_customer.

    " Company Code
    IF is_payment-company_code IS NOT INITIAL.
      INSERT is_payment-company_code INTO TABLE lt_company_code.
    ENDIF.

    DATA(lt_cc_info) = go_master_data->get_company_codes( lt_company_code ).

    IF is_payment-company_code IS NOT INITIAL
    AND NOT line_exists( lt_cc_info[ company_code = is_payment-company_code ] ).
      APPEND VALUE #( msgno         = '200'
                      msgtx         = message_text( iv_msgno = '200'
                                                    iv_v1    = |{ is_payment-company_code }| )
                      salesforce_id = is_payment-salesforce_id
                      field         = zcl_zari002_json=>to_json_name( 'company_code' )
                    ) TO rt_error.
      RETURN.
    ENDIF.

    " G/L Account
    IF is_payment-gl_account IS NOT INITIAL.
      INSERT VALUE #( company_code = is_payment-company_code
                      gl_account   = is_payment-gl_account
                    ) INTO TABLE lt_gl_key.

      IF go_master_data->find_unknown_gl_accounts( lt_gl_key ) IS NOT INITIAL.
        APPEND VALUE #( msgno         = '201'
                        msgtx         = message_text( iv_msgno = '201'
                                                      iv_v1    = |{ is_payment-gl_account }|
                                                      iv_v2    = |{ is_payment-company_code }| )
                        salesforce_id = is_payment-salesforce_id
                        field         = zcl_zari002_json=>to_json_name( 'gl_account' )
                      ) TO rt_error.
      ENDIF.
    ENDIF.

    " Payment Method
    DATA(lv_country) = VALUE zif_zari002_master_data=>ty_country(
      lt_cc_info[ company_code = is_payment-company_code ]-country OPTIONAL ).

    IF is_payment-sap_payment_method IS INITIAL.
      IF is_payment-payment_method IS NOT INITIAL.
        APPEND VALUE #( msgno         = '202'
                        msgtx         = message_text( iv_msgno = '202'
                                                      iv_v1    = |{ is_payment-payment_method }| )
                        salesforce_id = is_payment-salesforce_id
                        field         = zcl_zari002_json=>to_json_name( 'payment_method' )
                      ) TO rt_error.
      ENDIF.
    ELSEIF lv_country IS NOT INITIAL.
      INSERT VALUE #( country        = lv_country
                      payment_method = is_payment-sap_payment_method
                    ) INTO TABLE lt_pm_key.

      IF go_master_data->find_unknown_pymt_methods( lt_pm_key ) IS NOT INITIAL.
        APPEND VALUE #( msgno         = '203'
                        msgtx         = message_text( iv_msgno = '203'
                                                      iv_v1    = |{ is_payment-sap_payment_method }|
                                                      iv_v2    = |{ lv_country }| )
                        salesforce_id = is_payment-salesforce_id
                        field         = zcl_zari002_json=>to_json_name( 'payment_method' )
                      ) TO rt_error.
      ENDIF.
    ENDIF.

    " Customer
    LOOP AT it_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
      IF <lfs_item>-customer_code IS NOT INITIAL.
        INSERT <lfs_item>-customer_code INTO TABLE lt_customer.
      ENDIF.
    ENDLOOP.

    DATA(lt_unknown_cust) = go_master_data->find_unknown_customers( lt_customer ).

    LOOP AT it_item ASSIGNING <lfs_item>.
      IF <lfs_item>-customer_code IS NOT INITIAL
      AND line_exists( lt_unknown_cust[ table_line = <lfs_item>-customer_code ] ).
        APPEND VALUE #( msgno              = '205'
                        msgtx              = message_text( iv_msgno = '205'
                                                           iv_v1    = |{ <lfs_item>-customer_code }| )
                        salesforce_id      = is_payment-salesforce_id
                        salesforce_item_id = <lfs_item>-salesforce_item_id
                        field              = zcl_zari002_json=>to_json_name( 'customer_code' )
                      ) TO rt_error.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD check_duplicate.

    IF is_payment-payment_document_no IS INITIAL.
      RETURN.
    ENDIF.

    DATA lr_billing TYPE RANGE OF ztar_i002_item-billing_document.

    LOOP AT it_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
      IF <lfs_item>-billing_document IS NOT INITIAL
     AND NOT line_exists( lr_billing[ low = <lfs_item>-billing_document ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_item>-billing_document )
                     TO lr_billing.
      ENDIF.
    ENDLOOP.

*   range ว่างแปลว่า IN จะ match ทุกแถว — ต้องออกก่อน
    IF lr_billing IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM ztar_i002_pymt AS p
           INNER JOIN ztar_i002_item AS i ON i~payment_uuid = p~payment_uuid
      FIELDS i~billing_document
      WHERE p~payment_document_no = @is_payment-payment_document_no
        AND i~billing_document    IN @lr_billing
      INTO TABLE @DATA(lt_existing).

    LOOP AT it_item ASSIGNING <lfs_item>.
      IF line_exists( lt_existing[ billing_document = <lfs_item>-billing_document ] ).
        APPEND VALUE #( msgno              = '010'
                        msgtx              = message_text( iv_msgno = '010'
                                                           iv_v1    = |{ is_payment-payment_document_no }|
                                                           iv_v2    = |{ <lfs_item>-billing_document }| )
                        salesforce_id      = is_payment-salesforce_id
                        salesforce_item_id = <lfs_item>-salesforce_item_id
                        field              = zcl_zari002_json=>to_json_name( 'payment_document_no' )
                      ) TO rt_error.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD save.

    INSERT ztar_i002_pymt FROM @is_payment.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      RETURN.
    ENDIF.

    INSERT ztar_i002_item FROM TABLE @it_item.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      RETURN.
    ENDIF.

    COMMIT WORK AND WAIT.
    rv_result = abap_true.

  ENDMETHOD.


  METHOD send_callback.

    DATA lt_result TYPE zcl_zari003_sfdc_notify=>tt_result.

    DATA(lv_status) = COND #( WHEN it_error IS INITIAL
                              THEN zcl_zari003_sfdc_notify=>gc_status_success
                              ELSE zcl_zari003_sfdc_notify=>gc_status_error ).

*   error ที่ระบุ item ได้ ให้ไปอยู่กับ item นั้น · ที่เหลือเป็น error ระดับ payment
*   ใช้กับทุกบรรทัดเพราะ reject-all — ทั้งใบตกไปด้วยกัน
    DATA(lv_common) = concat_lines_of(
      table = VALUE string_table( FOR <lfs_e> IN it_error
                                  WHERE ( salesforce_item_id IS INITIAL ) ( <lfs_e>-msgtx ) )
      sep   = ` · ` ).

    LOOP AT it_item ASSIGNING FIELD-SYMBOL(<lfs_item>).

      DATA(lv_text) = concat_lines_of(
        table = VALUE string_table(
                  FOR <lfs_ie> IN it_error
                  WHERE ( salesforce_item_id = <lfs_item>-salesforce_item_id ) ( <lfs_ie>-msgtx ) )
        sep   = ` · ` ).

      IF lv_common IS NOT INITIAL.
        lv_text = COND #( WHEN lv_text IS INITIAL THEN lv_common
                          ELSE |{ lv_common } · { lv_text }| ).
      ENDIF.

      APPEND VALUE #( salesforce_id      = is_payment-salesforce_id
                      salesforce_item_id = <lfs_item>-salesforce_item_id
                      status             = lv_status
                      error_message      = lv_text ) TO lt_result.

    ENDLOOP.

    go_notify->notify( lt_result ).

  ENDMETHOD.


  METHOD to_errors.

    LOOP AT it_finding ASSIGNING FIELD-SYMBOL(<lfs_finding>).
      APPEND VALUE #( msgno              = <lfs_finding>-msgno
                      msgtx              = message_text( iv_msgno = <lfs_finding>-msgno
                                                         iv_v1    = <lfs_finding>-msgv1
                                                         iv_v2    = <lfs_finding>-msgv2
                                                         iv_v3    = <lfs_finding>-msgv3
                                                         iv_v4    = <lfs_finding>-msgv4 )
                      salesforce_id      = iv_salesforce_id
                      salesforce_item_id = iv_salesforce_item_id
                      field              = zcl_zari002_json=>to_json_name( <lfs_finding>-field )
                    ) TO rt_error.
    ENDLOOP.

  ENDMETHOD.


  METHOD message_text.

    MESSAGE ID 'ZARI002' TYPE 'E' NUMBER iv_msgno
    WITH iv_v1 iv_v2 iv_v3 iv_v4
    INTO rv_result.

  ENDMETHOD.

ENDCLASS.
