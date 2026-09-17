CLASS zcl_zari002_processor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      ty_request TYPE zcl_zari002_http=>ty_request,
      ty_payment TYPE ztar_i002_pymt,
      ty_item    TYPE ztar_i002_item,
      tt_item    TYPE STANDARD TABLE OF ztar_i002_item WITH EMPTY KEY,
      ty_hdr_log TYPE ztar_i002_hdrlog,
      tt_itm_log TYPE STANDARD TABLE OF ztar_i002_itmlog WITH EMPTY KEY,
      tt_msg_log TYPE STANDARD TABLE OF ztar_i002_msglog WITH EMPTY KEY.

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
                io_notify      TYPE REF TO zcl_zari002_sfdc_notify OPTIONAL.

    "! flow เดียวจบ: parse → normalize → validate → save → callback
    METHODS process
      IMPORTING iv_body          TYPE string
      RETURNING VALUE(rs_result) TYPE ty_result.

  PRIVATE SECTION.

    DATA go_master_data TYPE REF TO zif_zari002_master_data.
    DATA go_notify      TYPE REF TO zcl_zari002_sfdc_notify.

    "! เตรียม payment ให้พร้อมลง table — UUID · key padding · แปลง payment method · admin field
    "! ถ้า UUID สร้างไม่ได้ คืน error กลับมาแบบเดียวกับ validate( ) ให้ process( ) รวมเข้าเส้นทางเดียวกัน
    METHODS normalize
      IMPORTING iv_request_id   TYPE ztar_i002_pymt-request_id
      CHANGING  cs_payment      TYPE ztar_i002_pymt
                ct_item         TYPE tt_item
      RETURNING VALUE(rt_error) TYPE tt_error.

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

    "! สรุปผลรวมของทั้ง request จากตัวนับ — ต้องเรียกก่อน RETURN ทุกทาง
    "! ไม่งั้นทางที่ออกก่อนจะคืน Status เป็นค่าว่าง
    METHODS set_outcome
      CHANGING cs_result TYPE ty_result.

    "! เขียน log 3 table สำหรับ payment ใบนี้ ทั้งผ่านและตก — LUW แยกจาก business save
    "! ล้มแล้วต้องไม่ทำ request หลักพัง (log เป็นของรอง)
    METHODS save_log
      IMPORTING is_payment TYPE ty_payment
                it_item    TYPE tt_item
                it_error   TYPE tt_error
                is_raw     TYPE zcl_zari002_http=>ty_payment.

    "! HDRLOG จาก payment ที่ normalize แล้ว · status = ผลรับของ ZARI002 ไม่ใช่ผล post
    METHODS to_hdr_log
      IMPORTING is_payment       TYPE ty_payment
                it_error         TYPE tt_error
                is_raw           TYPE zcl_zari002_http=>ty_payment
      RETURNING VALUE(rs_result) TYPE ty_hdr_log.

    "! ITMLOG — field ชื่อตรงกับ ZTAR_I002_ITEM ทั้งหมด
    METHODS to_itm_log
      IMPORTING it_item          TYPE tt_item
      RETURNING VALUE(rt_result) TYPE tt_itm_log.

    "! MSGLOG 1 row ต่อ 1 error · area ตัดสินจาก salesforce_item_id · ใบผ่านไม่มี row
    METHODS to_msg_log
      IMPORTING is_payment       TYPE ty_payment
                it_error         TYPE tt_error
      RETURNING VALUE(rt_result) TYPE tt_msg_log
      RAISING   cx_uuid_error.

    "! JSON ของ payment ใบนี้ตามที่ SBPA ส่งมา serialize จาก structure ดิบก่อน normalize
    METHODS to_request_body
      IMPORTING is_raw           TYPE zcl_zari002_http=>ty_payment
      RETURNING VALUE(rv_result) TYPE ztar_i002_hdrlog-request_body.

    "! จัด JSON compact ให้ขึ้นบรรทัดและย่อหน้า เพื่อให้อ่านได้ในหน้า monitor
    METHODS to_pretty_json
      IMPORTING iv_json          TYPE string
      RETURNING VALUE(rv_result) TYPE string.

ENDCLASS.



CLASS zcl_zari002_processor IMPLEMENTATION.

  METHOD constructor.

    go_master_data = COND #( WHEN io_master_data IS BOUND THEN io_master_data
                             ELSE NEW zcl_zari002_master_data( ) ).

    go_notify = COND #( WHEN io_notify IS BOUND THEN io_notify
                        ELSE NEW zcl_zari002_sfdc_notify( ) ).

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
        APPEND VALUE #( msgno = '012'
                        msgtx = message_text( '012' )
                      ) TO rs_result-errors.
        set_outcome( CHANGING cs_result = rs_result ).
        RETURN.
    ENDTRY.

    " 2. Request ID ----------------------------------------------------
    IF ls_request-request_id IS INITIAL.
      ls_request-request_id = |{ cl_abap_context_info=>get_system_date( ) }_| &&
                              |{ cl_abap_context_info=>get_system_time( ) }|.
    ENDIF.

    rs_result-request_id = ls_request-request_id.

    " 3. Empty Payment -------------------------------------------------
    IF ls_request-payments IS INITIAL.
      APPEND VALUE #( msgno = '013'
                      msgtx = message_text( '013' )
                    ) TO rs_result-errors.
      set_outcome( CHANGING cs_result = rs_result ).
      RETURN.
    ENDIF.

    " 4. Process -------------------------------------------------------
    LOOP AT ls_request-payments ASSIGNING FIELD-SYMBOL(<lfs_payment>).

      CLEAR: ls_payment, lt_item[].
      MOVE-CORRESPONDING <lfs_payment>       TO ls_payment.
      MOVE-CORRESPONDING <lfs_payment>-items TO lt_item.

      " 4.1 Normalize --------------------------------------------------
      DATA(lt_error) = normalize( EXPORTING iv_request_id = CONV #( ls_request-request_id )
                                  CHANGING  cs_payment    = ls_payment
                                            ct_item       = lt_item ).

      " 4.2 Validate — ข้ามถ้า normalize พัง ไม่งั้นจะได้ error ซ้อนจาก field ที่ยังไม่ได้เตรียม
      IF lt_error IS INITIAL.
        lt_error = validate( is_payment = ls_payment
                             it_item    = lt_item ).
      ENDIF.

      " 4.3 Save -------------------------------------------------------
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

      " 4.4 Log — ทุกใบ ทั้งผ่านและตก ------------------------------------
      "     ข้ามถ้าไม่มี UUID (normalize สร้างไม่ได้) เพราะไม่มี key ให้เขียน
      IF ls_payment-payment_uuid IS NOT INITIAL.
        save_log( is_payment = ls_payment
                  it_item    = lt_item
                  it_error   = lt_error
                  is_raw     = <lfs_payment> ).
      ENDIF.

      " 4.5 Callback ---------------------------------------------------
      send_callback( is_payment = ls_payment
                     it_item    = lt_item
                     it_error   = lt_error ).

    ENDLOOP.

    set_outcome( CHANGING cs_result = rs_result ).

  ENDMETHOD.


  METHOD normalize.

    DATA lt_company_code TYPE zif_zari002_master_data=>tt_company_code.

    " 1. Payment -------------------------------------------------------
    " Payment UUID
    TRY.
        cs_payment-payment_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lo_uuid_error).
        APPEND VALUE #( msgno         = '000'
                        msgtx         = lo_uuid_error->get_text( )
                        salesforce_id = cs_payment-salesforce_id
                      ) TO rt_error.
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
          APPEND VALUE #( msgno              = '000'
                          msgtx              = lo_uuid_error->get_text( )
                          salesforce_id      = cs_payment-salesforce_id
                          salesforce_item_id = <lfs_item>-salesforce_item_id
                        ) TO rt_error.
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
    APPEND LINES OF to_errors( it_finding       = zcl_zari002_validator=>check_payment_mandatory( is_payment )
                               iv_salesforce_id = is_payment-salesforce_id
                             ) TO rt_error.

    APPEND LINES OF to_errors( it_finding       = zcl_zari002_validator=>check_dates( is_payment )
                               iv_salesforce_id = is_payment-salesforce_id
                             ) TO rt_error.

    APPEND LINES OF to_errors( it_finding       = zcl_zari002_validator=>check_cheque_fields( is_payment )
                               iv_salesforce_id = is_payment-salesforce_id
                             ) TO rt_error.

    APPEND LINES OF to_errors( it_finding       = zcl_zari002_validator=>check_number_of_items(
                                                    iv_number_of_items = is_payment-number_of_items_in_payment
                                                    iv_item_count      = lines( it_item ) )
                               iv_salesforce_id = is_payment-salesforce_id
                             ) TO rt_error.

    APPEND LINES OF to_errors( it_finding       = zcl_zari002_validator=>check_amount_paid_total(
                                                    iv_salesforce_id = is_payment-salesforce_id
                                                    it_item          = it_item )
                               iv_salesforce_id = is_payment-salesforce_id
                             ) TO rt_error.

    APPEND LINES OF to_errors( it_finding       = zcl_zari002_validator=>check_item_ids( it_item )
                               iv_salesforce_id = is_payment-salesforce_id
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
*   check_payment_total       → 007 (OQ-05)

  ENDMETHOD.


  METHOD check_master_data.

    DATA lt_company_code     TYPE zif_zari002_master_data=>tt_company_code.
    DATA lt_gl_key           TYPE zif_zari002_master_data=>tt_gl_key.
    DATA lt_pm_key           TYPE zif_zari002_master_data=>tt_payment_method_key.
    DATA lt_customer         TYPE zif_zari002_master_data=>tt_customer.
    DATA lt_bank_key         TYPE zif_zari002_master_data=>tt_bank_key.
    DATA lt_billing_document TYPE zif_zari002_master_data=>tt_billing_document.

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

    " Bank / Branch — ตรวจเฉพาะตอนจ่ายด้วยเช็คเท่านั้น
    IF is_payment-sap_payment_method  = zcl_zari002_validator=>gc_pymt_method_cheque
    AND is_payment-cheque_bank_branch IS NOT INITIAL
    AND lv_country                    IS NOT INITIAL.

      INSERT VALUE #( country = lv_country
                      bank    = is_payment-cheque_bank_branch
                    ) INTO TABLE lt_bank_key.

      IF go_master_data->find_unknown_banks( lt_bank_key ) IS NOT INITIAL.
        APPEND VALUE #( msgno         = '207'
                        msgtx         = message_text( iv_msgno = '207'
                                                      iv_v1    = |{ is_payment-cheque_bank_branch }| )
                        salesforce_id = is_payment-salesforce_id
                        field         = zcl_zari002_json=>to_json_name( 'cheque_bank_branch' )
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

    " AR Open Item — billing document ต้องยังเปิดอยู่ใน FI (ยังไม่ถูก clear / reverse)
    " ทำงานคู่กับ duplicate check: ใบที่ post แล้ว (S/W) จะถูกจับที่นี่ เพราะการ post ทำให้ clear
    LOOP AT it_item ASSIGNING <lfs_item>.
      IF <lfs_item>-billing_document IS NOT INITIAL.
        INSERT <lfs_item>-billing_document INTO TABLE lt_billing_document.
      ENDIF.
    ENDLOOP.

    DATA(lt_cleared) = go_master_data->find_cleared_documents( lt_billing_document ).

    LOOP AT it_item ASSIGNING <lfs_item>.
      IF <lfs_item>-billing_document IS NOT INITIAL
      AND line_exists( lt_cleared[ table_line = <lfs_item>-billing_document ] ).
        APPEND VALUE #( msgno              = '206'
                        msgtx              = message_text( iv_msgno = '206'
                                                           iv_v1    = |{ <lfs_item>-billing_document }| )
                        salesforce_id      = is_payment-salesforce_id
                        salesforce_item_id = <lfs_item>-salesforce_item_id
                        field              = zcl_zari002_json=>to_json_name( 'billing_document' )
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

*   status เป็นส่วนของ key — ใบเข้ามาใหม่เป็น N เสมอ จึงซ้ำเฉพาะเมื่อมี row N อยู่แล้ว
*     E (post ไม่ผ่าน)  → ไม่ซ้ำ ส่งแก้เข้ามาใหม่ได้
*     S/W (post แล้ว)   → ไม่ซ้ำที่นี่ แต่ AR open item check จับได้ เพราะ document ถูก clear แล้ว
*     N (ยังไม่ทำอะไร)  → ซ้ำ
*   ห้ามใช้โดยไม่มี AR open item check — ไม่งั้นใบ S ส่งซ้ำแล้ว post ซ้ำได้
    SELECT FROM ztar_i002_pymt AS p
           INNER JOIN ztar_i002_item AS i ON i~payment_uuid = p~payment_uuid
      FIELDS i~billing_document
      WHERE p~payment_document_no = @is_payment-payment_document_no
        AND p~status              = @is_payment-status
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

    DATA lt_result TYPE zcl_zari002_sfdc_notify=>tt_result.

    DATA(lv_status) = COND #( WHEN it_error IS INITIAL
                              THEN zcl_zari002_sfdc_notify=>gc_status_success
                              ELSE zcl_zari002_sfdc_notify=>gc_status_error ).

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

*   item id: finding ที่ระบุเองมาก่อน (check ที่วนหลาย item) ถ้าไม่มีค่อยใช้ของผู้เรียก
    LOOP AT it_finding ASSIGNING FIELD-SYMBOL(<lfs_finding>).
      APPEND VALUE #( msgno              = <lfs_finding>-msgno
                      msgtx              = message_text( iv_msgno = <lfs_finding>-msgno
                                                         iv_v1    = <lfs_finding>-msgv1
                                                         iv_v2    = <lfs_finding>-msgv2
                                                         iv_v3    = <lfs_finding>-msgv3
                                                         iv_v4    = <lfs_finding>-msgv4 )
                      salesforce_id      = iv_salesforce_id
                      salesforce_item_id = COND #( WHEN <lfs_finding>-salesforce_item_id IS NOT INITIAL
                                                   THEN <lfs_finding>-salesforce_item_id
                                                   ELSE iv_salesforce_item_id )
                      field              = zcl_zari002_json=>to_json_name( <lfs_finding>-field )
                    ) TO rt_error.
    ENDLOOP.

  ENDMETHOD.


  METHOD message_text.

    MESSAGE ID 'ZARI002' TYPE 'E' NUMBER iv_msgno
    WITH iv_v1 iv_v2 iv_v3 iv_v4
    INTO rv_result.

  ENDMETHOD.


  METHOD set_outcome.

*   สำเร็จ = มีอย่างน้อย 1 ใบเข้า table · ตกบางใบยังได้ HTTP 200
*   จะเป็น 400 ก็ต่อเมื่อไม่มีอะไรเข้าเลย
    cs_result-success = xsdbool( cs_result-accepted > 0 ).

    cs_result-status = COND #(
      WHEN cs_result-accepted > 0 AND cs_result-rejected = 0 THEN message_text( '300' )
      WHEN cs_result-accepted > 0                            THEN message_text( '301' )
      ELSE                                                        message_text( '302' ) ).

  ENDMETHOD.


  METHOD save_log.

    TRY.
        DATA(ls_hdr_log) = to_hdr_log( is_payment = is_payment
                                       it_error   = it_error
                                       is_raw     = is_raw ).
        DATA(lt_itm_log) = to_itm_log( it_item ).
        DATA(lt_msg_log) = to_msg_log( is_payment = is_payment
                                       it_error   = it_error ).

        INSERT ztar_i002_hdrlog FROM @ls_hdr_log.
        IF sy-subrc <> 0.
          ROLLBACK WORK.
          RETURN.
        ENDIF.

*       ตารางลูกว่างเป็นเรื่องปกติ — INSERT FROM TABLE ที่ไม่มีแถวคืน sy-subrc = 4
        IF lt_itm_log IS NOT INITIAL.
          INSERT ztar_i002_itmlog FROM TABLE @lt_itm_log.
          IF sy-subrc <> 0.
            ROLLBACK WORK.
            RETURN.
          ENDIF.
        ENDIF.

        IF lt_msg_log IS NOT INITIAL.
          INSERT ztar_i002_msglog FROM TABLE @lt_msg_log.
          IF sy-subrc <> 0.
            ROLLBACK WORK.
            RETURN.
          ENDIF.
        ENDIF.

        COMMIT WORK AND WAIT.

      CATCH cx_root.
*       log เขียนไม่ได้ก็ปล่อย — business save commit ไปแล้ว ไม่กระทบ
        ROLLBACK WORK.
    ENDTRY.

  ENDMETHOD.


  METHOD to_hdr_log.

    MOVE-CORRESPONDING is_payment TO rs_result.

    rs_result-status             = COND #( WHEN it_error IS INITIAL THEN 'S' ELSE 'E' ).
    rs_result-request_body       = to_request_body( is_raw ).
    CLEAR: rs_result-salesforce_status,
           rs_result-salesforce_message.

  ENDMETHOD.


  METHOD to_itm_log.

    LOOP AT it_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
*     item ที่ไม่มี UUID เขียนไม่ได้ (normalize สร้างไม่ได้) — ข้ามเฉพาะแถวนั้น
      IF <lfs_item>-item_uuid IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND CORRESPONDING #( <lfs_item> ) TO rt_result.
    ENDLOOP.

  ENDMETHOD.


  METHOD to_msg_log.

    LOOP AT it_error ASSIGNING FIELD-SYMBOL(<lfs_error>).

      APPEND VALUE #( message_uuid          = cl_system_uuid=>create_uuid_x16_static( )
                      payment_uuid          = is_payment-payment_uuid
                      msg_seq               = sy-tabix
                      message_area          = COND #( WHEN <lfs_error>-salesforce_item_id IS NOT INITIAL
                                                      THEN 'ITEM' ELSE 'HEADER' )
                      salesforce_item_id    = <lfs_error>-salesforce_item_id
                      status                = 'E'
                      message               = |ZARI002/{ <lfs_error>-msgno } { <lfs_error>-msgtx }|
                      created_by            = is_payment-created_by
                      created_at            = is_payment-created_at
                      last_changed_by       = is_payment-last_changed_by
                      last_changed_at       = is_payment-last_changed_at
                      local_last_changed_at = is_payment-local_last_changed_at
                    ) TO rt_result.

    ENDLOOP.

  ENDMETHOD.


  METHOD to_request_body.

    TRY.
        rv_result = to_pretty_json( xco_cp_json=>data->from_abap( is_raw
                      )->apply( VALUE #( ( xco_cp_json=>transformation->underscore_to_pascal_case ) )
                      )->to_string( ) ).
      CATCH cx_root.
        CLEAR rv_result.
    ENDTRY.

  ENDMETHOD.


  METHOD to_pretty_json.

*   HTML ยุบ space นำหน้าบรรทัดทิ้ง ใช้ non-breaking space แทนเพื่อให้ indent ติดไปด้วย
    DATA(lv_nbsp)   = cl_abap_conv_codepage=>create_in( )->convert( CONV xstring( 'C2A0' ) ).
    DATA(lv_indent) = lv_nbsp && lv_nbsp.

    DATA lt_line      TYPE string_table.
    DATA lv_line      TYPE string.
    DATA lv_level     TYPE i.
    DATA lv_in_string TYPE abap_bool.
    DATA lv_escaped   TYPE abap_bool.
    DATA lv_off       TYPE i.

    DATA(lv_len) = strlen( iv_json ).

    WHILE lv_off < lv_len.

      DATA(lv_char) = substring( val = iv_json off = lv_off len = 1 ).

*     ---- อยู่ใน string literal ปล่อยผ่านทุกตัวอักษร ----
      IF lv_in_string = abap_true.
        lv_line = lv_line && lv_char.
        IF lv_escaped = abap_true.
          lv_escaped = abap_false.
        ELSEIF lv_char = `\`.
          lv_escaped = abap_true.
        ELSEIF lv_char = `"`.
          lv_in_string = abap_false.
        ENDIF.
        lv_off = lv_off + 1.
        CONTINUE.
      ENDIF.

*     ---- นอก string literal ----
      CASE lv_char.

        WHEN `"`.
          lv_in_string = abap_true.
          lv_line      = lv_line && lv_char.

        WHEN `{` OR `[`.
          DATA(lv_next) = COND string( WHEN lv_off + 1 < lv_len
                                       THEN substring( val = iv_json off = lv_off + 1 len = 1 ) ).
*         container ว่างเขียนติดกันไปเลย
          IF ( lv_char = `{` AND lv_next = `}` ) OR ( lv_char = `[` AND lv_next = `]` ).
            lv_line = lv_line && lv_char && lv_next.
            lv_off  = lv_off + 2.
            CONTINUE.
          ENDIF.
          lv_line = lv_line && lv_char.
          APPEND lv_line TO lt_line.
          lv_level = lv_level + 1.
          lv_line  = repeat( val = lv_indent occ = lv_level ).

        WHEN `}` OR `]`.
          APPEND lv_line TO lt_line.
          lv_level = lv_level - 1.
          lv_line  = repeat( val = lv_indent occ = lv_level ) && lv_char.

        WHEN `,`.
          lv_line = lv_line && lv_char.
          APPEND lv_line TO lt_line.
          lv_line = repeat( val = lv_indent occ = lv_level ).

        WHEN `:`.
          lv_line = lv_line && lv_char && ` `.

        WHEN OTHERS.
          lv_line = lv_line && lv_char.

      ENDCASE.

      lv_off = lv_off + 1.

    ENDWHILE.

    APPEND lv_line TO lt_line.
    rv_result = concat_lines_of( table = lt_line sep = |\n| ).

  ENDMETHOD.

ENDCLASS.
