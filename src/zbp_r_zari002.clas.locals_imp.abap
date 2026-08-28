CLASS lhc_Payment DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PUBLIC SECTION.

    "! ให้ unit test ใส่ test double แทน implementation จริงได้
    CLASS-METHODS set_master_data
      IMPORTING io_master_data TYPE REF TO zif_zari002_master_data.

    "! คืน md check ตัวที่ใช้อยู่ สร้าง implementation จริงถ้ายังไม่มีใครใส่ไว้
    CLASS-METHODS master_data
      RETURNING VALUE(ro_result) TYPE REF TO zif_zari002_master_data.

  PRIVATE SECTION.

    TYPES:
      ty_pay          TYPE STRUCTURE FOR READ RESULT zr_zari002,
      tt_pay_failed   TYPE TABLE FOR FAILED LATE zr_zari002,
      tt_pay_reported TYPE TABLE FOR REPORTED LATE zr_zari002.

    CLASS-DATA go_master_data TYPE REF TO zif_zari002_master_data.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR Payment RESULT result.

    METHODS setPaymentDefaults FOR DETERMINE ON SAVE
       keys FOR Payment~setPaymentDefaults.

    METHODS setPaymentMethodCode FOR DETERMINE ON SAVE
       keys FOR Payment~setPaymentMethodCode.

    METHODS validateAmountFormat FOR VALIDATE ON SAVE
       keys FOR Payment~validateAmountFormat.

    METHODS validateAmountPaidTotal FOR VALIDATE ON SAVE
       keys FOR Payment~validateAmountPaidTotal.

    METHODS validateChequeBankBranch FOR VALIDATE ON SAVE
       keys FOR Payment~validateChequeBankBranch.

    METHODS validateChequeFields FOR VALIDATE ON SAVE
       keys FOR Payment~validateChequeFields.

    METHODS validateCompanyCode FOR VALIDATE ON SAVE
       keys FOR Payment~validateCompanyCode.

    METHODS validateDates FOR VALIDATE ON SAVE
       keys FOR Payment~validateDates.

    METHODS validateGLAccount FOR VALIDATE ON SAVE
       keys FOR Payment~validateGLAccount.

    METHODS validateItemDuplicate FOR VALIDATE ON SAVE
       keys FOR Payment~validateItemDuplicate.

    METHODS validateMandatory FOR VALIDATE ON SAVE
       keys FOR Payment~validateMandatory.

    METHODS validateNumberOfItems FOR VALIDATE ON SAVE
       keys FOR Payment~validateNumberOfItems.

    METHODS validatePaymentMethod FOR VALIDATE ON SAVE
       keys FOR Payment~validatePaymentMethod.

    METHODS validatePaymentTotal FOR VALIDATE ON SAVE
       keys FOR Payment~validatePaymentTotal.

    "! แปลง finding จาก validator เป็น RAP message พร้อมชี้ field ที่ผิด
    METHODS report_payment
      IMPORTING is_payment  TYPE ty_pay
                it_finding  TYPE zcl_zari002_validator=>tt_finding
      CHANGING  ct_failed   TYPE tt_pay_failed
                ct_reported TYPE tt_pay_reported.

ENDCLASS.

CLASS lhc_Payment IMPLEMENTATION.

  METHOD set_master_data.
    go_master_data = io_master_data.
  ENDMETHOD.

  METHOD master_data.
    IF go_master_data IS NOT BOUND.
      go_master_data = NEW zcl_zari002_master_data( ).
    ENDIF.
    ro_result = go_master_data.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD setPaymentDefaults.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_payment).

    IF lt_payment IS INITIAL.
      RETURN.
    ENDIF.

*   batch_id เดียวกันทั้ง request — คิดครั้งเดียวนอก loop
    DATA(lv_batch_id) = |{ cl_abap_context_info=>get_system_date( ) }_| &&
                        |{ cl_abap_context_info=>get_system_time( ) }|.

*   อ่าน company code ทั้งชุดครั้งเดียว ไม่ใช่ทีละ payment
    DATA lt_company_code TYPE zif_zari002_master_data=>tt_company_code.

    LOOP AT lt_payment ASSIGNING FIELD-SYMBOL(<lfs_pay>).
      INSERT <lfs_pay>-CompanyCode INTO TABLE lt_company_code.
    ENDLOOP.

    DATA(lt_cc_info) = master_data( )->get_company_codes( lt_company_code ).

*   จำ currency ของแต่ละ payment ไว้ เพื่อส่งต่อให้ item ท้าย method
    TYPES: BEGIN OF ty_currency_of,
             payment_uuid TYPE sysuuid_x16,
             currency     TYPE zif_zari002_master_data=>ty_currency,
           END OF ty_currency_of.

    DATA lt_currency_of TYPE SORTED TABLE OF ty_currency_of
                             WITH UNIQUE KEY payment_uuid.

    DATA lt_update TYPE TABLE FOR UPDATE zr_zari002.

    LOOP AT lt_payment ASSIGNING <lfs_pay>.

      DATA(lv_currency) = COND zif_zari002_master_data=>ty_currency(
        WHEN line_exists( lt_cc_info[ company_code = <lfs_pay>-CompanyCode ] )
        THEN lt_cc_info[ company_code = <lfs_pay>-CompanyCode ]-currency ).

      INSERT VALUE #( payment_uuid = <lfs_pay>-PaymentUUID
                      currency     = lv_currency ) INTO TABLE lt_currency_of.

      APPEND VALUE #( %tky      = <lfs_pay>-%tky
                      BatchId   = lv_batch_id
                      Currency  = lv_currency
                      GLAccount = zcl_zari002_validator=>to_internal_key( <lfs_pay>-GLAccount )
                      Status    = 'N' ) TO lt_update.

    ENDLOOP.

    MODIFY ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        UPDATE FIELDS ( BatchId Currency GLAccount Status )
        WITH lt_update.

*   push currency ลง item ที่นี่ ไม่ใช่ใน setItemDefaults
*   เพราะ RAP ไม่รับประกันลำดับ determination ข้าม entity (01_architecture.md §7)
    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment BY \_Item
        FIELDS ( PaymentUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    DATA lt_item_update TYPE TABLE FOR UPDATE zi_zari002_item.

    LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
      APPEND VALUE #( %tky     = <lfs_item>-%tky
                      Currency = VALUE #( lt_currency_of[ payment_uuid = <lfs_item>-PaymentUUID ]-currency
                                          OPTIONAL ) )
             TO lt_item_update.
    ENDLOOP.

    MODIFY ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( Currency )
        WITH lt_item_update.

  ENDMETHOD.

  METHOD setPaymentMethodCode.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        FIELDS ( PaymentMethod )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_payment).

    DATA lt_update TYPE TABLE FOR UPDATE zr_zari002.

    LOOP AT lt_payment ASSIGNING FIELD-SYMBOL(<lfs_pay>).
      APPEND VALUE #(
        %tky             = <lfs_pay>-%tky
        SapPaymentMethod = zcl_zari002_validator=>convert_payment_method( <lfs_pay>-PaymentMethod ) )
        TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        UPDATE FIELDS ( SapPaymentMethod )
        WITH lt_update.

  ENDMETHOD.

  METHOD validateAmountFormat.
  ENDMETHOD.

  METHOD validateAmountPaidTotal.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_payment).

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_payment ASSIGNING FIELD-SYMBOL(<lfs_pay>).

      DATA lt_own_item LIKE lt_item.
      CLEAR lt_own_item.

      LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<lfs_item>)
           WHERE PaymentUUID = <lfs_pay>-PaymentUUID.
        APPEND <lfs_item> TO lt_own_item.
      ENDLOOP.

      report_payment(
        EXPORTING is_payment  = <lfs_pay>
                  it_finding  = zcl_zari002_validator=>check_amount_paid_total(
                                  iv_salesforce_id = <lfs_pay>-SalesforceId
                                  it_item          = lt_own_item )
        CHANGING  ct_failed   = failed-payment
                  ct_reported = reported-payment ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validateChequeBankBranch.
  ENDMETHOD.

  METHOD validateChequeFields.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_payment).

    LOOP AT lt_payment ASSIGNING FIELD-SYMBOL(<lfs_pay>).
      report_payment(
        EXPORTING is_payment  = <lfs_pay>
                  it_finding  = zcl_zari002_validator=>check_cheque_fields( <lfs_pay> )
        CHANGING  ct_failed   = failed-payment
                  ct_reported = reported-payment ).
    ENDLOOP.

  ENDMETHOD.

  METHOD validateCompanyCode.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_payment).

    DATA lt_company_code TYPE zif_zari002_master_data=>tt_company_code.

    LOOP AT lt_payment ASSIGNING FIELD-SYMBOL(<lfs_pay>).
      IF <lfs_pay>-CompanyCode IS NOT INITIAL.
        INSERT <lfs_pay>-CompanyCode INTO TABLE lt_company_code.
      ENDIF.
    ENDLOOP.

    DATA(lt_known) = lhc_Payment=>master_data( )->get_company_codes( lt_company_code ).

    LOOP AT lt_payment ASSIGNING <lfs_pay>.

*     ค่าว่างเป็นเรื่องของ validateMandatory ไม่ออก message ซ้ำที่นี่
      IF <lfs_pay>-CompanyCode IS INITIAL
      OR line_exists( lt_known[ company_code = <lfs_pay>-CompanyCode ] ).
        CONTINUE.
      ENDIF.

      report_payment(
        EXPORTING is_payment  = <lfs_pay>
                  it_finding  = VALUE #( ( msgno = '200'
                                           msgv1 = |{ <lfs_pay>-CompanyCode }|
                                           field = 'CompanyCode' ) )
        CHANGING  ct_failed   = failed-payment
                  ct_reported = reported-payment ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validateDates.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_payment).

    LOOP AT lt_payment ASSIGNING FIELD-SYMBOL(<lfs_pay>).
      report_payment(
        EXPORTING is_payment  = <lfs_pay>
                  it_finding  = zcl_zari002_validator=>check_dates( <lfs_pay> )
        CHANGING  ct_failed   = failed-payment
                  ct_reported = reported-payment ).
    ENDLOOP.

  ENDMETHOD.

  METHOD validateGLAccount.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_payment).

    DATA lt_gl_key TYPE zif_zari002_master_data=>tt_gl_key.

    LOOP AT lt_payment ASSIGNING FIELD-SYMBOL(<lfs_pay>).
      IF <lfs_pay>-CompanyCode IS NOT INITIAL AND <lfs_pay>-GLAccount IS NOT INITIAL.
        INSERT VALUE #( company_code = <lfs_pay>-CompanyCode
                        gl_account   = <lfs_pay>-GLAccount ) INTO TABLE lt_gl_key.
      ENDIF.
    ENDLOOP.

    DATA(lt_unknown) = lhc_Payment=>master_data( )->find_unknown_gl_accounts( lt_gl_key ).

    LOOP AT lt_payment ASSIGNING <lfs_pay>.

      IF NOT line_exists( lt_unknown[ company_code = <lfs_pay>-CompanyCode
                                      gl_account   = <lfs_pay>-GLAccount ] ).
        CONTINUE.
      ENDIF.

      report_payment(
        EXPORTING is_payment  = <lfs_pay>
                  it_finding  = VALUE #( ( msgno = '201'
                                           msgv1 = |{ <lfs_pay>-GLAccount }|
                                           msgv2 = |{ <lfs_pay>-CompanyCode }|
                                           field = 'GLAccount' ) )
        CHANGING  ct_failed   = failed-payment
                  ct_reported = reported-payment ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validateItemDuplicate.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_payment).

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

*   รวบ key ทั้งชุดแล้วยิง SELECT ครั้งเดียว
    DATA lr_doc_no  TYPE RANGE OF ztar_i002_pymt-payment_document_no.
    DATA lr_billing TYPE RANGE OF ztar_i002_item-billing_document.

    LOOP AT lt_payment ASSIGNING FIELD-SYMBOL(<lfs_pay>).
      IF <lfs_pay>-PaymentDocumentNo IS NOT INITIAL
     AND NOT line_exists( lr_doc_no[ low = <lfs_pay>-PaymentDocumentNo ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_pay>-PaymentDocumentNo )
               TO lr_doc_no.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
      IF <lfs_item>-BillingDocument IS NOT INITIAL
     AND NOT line_exists( lr_billing[ low = <lfs_item>-BillingDocument ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_item>-BillingDocument )
               TO lr_billing.
      ENDIF.
    ENDLOOP.

*   range ว่างแปลว่า IN จะ match ทุกแถว — ต้องออกก่อน
    IF lr_doc_no IS INITIAL OR lr_billing IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM ztar_i002_pymt AS p
           INNER JOIN ztar_i002_item AS i ON i~payment_uuid = p~payment_uuid
      FIELDS p~payment_document_no, i~billing_document
      WHERE p~payment_document_no IN @lr_doc_no
        AND i~billing_document    IN @lr_billing
      INTO TABLE @DATA(lt_existing).

    IF lt_existing IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_payment ASSIGNING <lfs_pay>.

      DATA lt_finding TYPE zcl_zari002_validator=>tt_finding.
      CLEAR lt_finding.

      LOOP AT lt_item ASSIGNING <lfs_item> WHERE PaymentUUID = <lfs_pay>-PaymentUUID.

        IF line_exists( lt_existing[ payment_document_no = <lfs_pay>-PaymentDocumentNo
                                     billing_document    = <lfs_item>-BillingDocument ] ).
          APPEND VALUE #( msgno = '010'
                          msgv1 = |{ <lfs_pay>-PaymentDocumentNo }|
                          msgv2 = |{ <lfs_item>-BillingDocument }|
                          field = 'PaymentDocumentNo' ) TO lt_finding.
        ENDIF.

      ENDLOOP.

      report_payment(
        EXPORTING is_payment  = <lfs_pay>
                  it_finding  = lt_finding
        CHANGING  ct_failed   = failed-payment
                  ct_reported = reported-payment ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validateMandatory.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_payment).

    LOOP AT lt_payment ASSIGNING FIELD-SYMBOL(<lfs_pay>).
      report_payment(
        EXPORTING is_payment  = <lfs_pay>
                  it_finding  = zcl_zari002_validator=>check_mandatory( <lfs_pay> )
        CHANGING  ct_failed   = failed-payment
                  ct_reported = reported-payment ).
    ENDLOOP.

  ENDMETHOD.

  METHOD validateNumberOfItems.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_payment).

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_payment ASSIGNING FIELD-SYMBOL(<lfs_pay>).

      DATA lv_count TYPE i.
      lv_count = 0.

      LOOP AT lt_item TRANSPORTING NO FIELDS
           WHERE PaymentUUID = <lfs_pay>-PaymentUUID.
        lv_count = lv_count + 1.
      ENDLOOP.

      report_payment(
        EXPORTING is_payment  = <lfs_pay>
                  it_finding  = zcl_zari002_validator=>check_number_of_items(
                                  iv_number_of_items = <lfs_pay>-NumberOfItemsInPayment
                                  iv_item_count      = lv_count )
        CHANGING  ct_failed   = failed-payment
                  ct_reported = reported-payment ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validatePaymentMethod.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Payment
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_payment).

*   country มาจาก company code จึงต้องอ่าน company code ก่อน
    DATA lt_company_code TYPE zif_zari002_master_data=>tt_company_code.

    LOOP AT lt_payment ASSIGNING FIELD-SYMBOL(<lfs_pay>).
      IF <lfs_pay>-CompanyCode IS NOT INITIAL.
        INSERT <lfs_pay>-CompanyCode INTO TABLE lt_company_code.
      ENDIF.
    ENDLOOP.

    DATA(lt_cc_info) = lhc_Payment=>master_data( )->get_company_codes( lt_company_code ).

    DATA lt_pm_key TYPE zif_zari002_master_data=>tt_payment_method_key.

    LOOP AT lt_payment ASSIGNING <lfs_pay>.

      IF <lfs_pay>-SapPaymentMethod IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_country) = VALUE zif_zari002_master_data=>ty_country(
        lt_cc_info[ company_code = <lfs_pay>-CompanyCode ]-country OPTIONAL ).

*     ไม่รู้ country ก็เช็คไม่ได้ — validateCompanyCode จับไปแล้ว
      IF lv_country IS NOT INITIAL.
        INSERT VALUE #( country        = lv_country
                        payment_method = <lfs_pay>-SapPaymentMethod )
               INTO TABLE lt_pm_key.
      ENDIF.

    ENDLOOP.

    DATA(lt_unknown) = lhc_Payment=>master_data( )->find_unknown_pymt_methods( lt_pm_key ).

    LOOP AT lt_payment ASSIGNING <lfs_pay>.

      DATA lt_finding TYPE zcl_zari002_validator=>tt_finding.
      CLEAR lt_finding.

      IF <lfs_pay>-SapPaymentMethod IS INITIAL.

*       แปลงคำไม่สำเร็จ — แจ้งคำที่ส่งมาเพื่อให้ SFDC รู้ว่าคำไหนไม่รู้จัก
        IF <lfs_pay>-PaymentMethod IS NOT INITIAL.
          lt_finding = VALUE #( ( msgno = '202'
                                  msgv1 = |{ <lfs_pay>-PaymentMethod }|
                                  field = 'PaymentMethod' ) ).
        ENDIF.

      ELSE.

        lv_country = VALUE #( lt_cc_info[ company_code = <lfs_pay>-CompanyCode ]-country OPTIONAL ).

        IF lv_country IS NOT INITIAL
       AND line_exists( lt_unknown[ country        = lv_country
                                    payment_method = <lfs_pay>-SapPaymentMethod ] ).
          lt_finding = VALUE #( ( msgno = '203'
                                  msgv1 = |{ <lfs_pay>-SapPaymentMethod }|
                                  msgv2 = |{ lv_country }|
                                  field = 'PaymentMethod' ) ).
        ENDIF.

      ENDIF.

      report_payment(
        EXPORTING is_payment  = <lfs_pay>
                  it_finding  = lt_finding
        CHANGING  ct_failed   = failed-payment
                  ct_reported = reported-payment ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validatePaymentTotal.
  ENDMETHOD.

  METHOD report_payment.

    IF it_finding IS INITIAL.
      RETURN.
    ENDIF.

    APPEND VALUE #( %tky = is_payment-%tky ) TO ct_failed.

    LOOP AT it_finding ASSIGNING FIELD-SYMBOL(<lfs_find>).

      DATA ls_reported LIKE LINE OF ct_reported.
      CLEAR ls_reported.

      ls_reported-%tky = is_payment-%tky.
      ls_reported-%msg = new_message( id       = 'ZARI002'
                                      number   = <lfs_find>-msgno
                                      severity = if_abap_behv_message=>severity-error
                                      v1       = <lfs_find>-msgv1
                                      v2       = <lfs_find>-msgv2 ).

*     ชี้ field ที่ผิดแบบ dynamic เพราะ validator คืนชื่อ field มาเป็น string
*     ถ้าชื่อไม่ตรงกับ element ใด ก็แค่ไม่ชี้ ไม่ทำให้ message หาย
      IF <lfs_find>-field IS NOT INITIAL.
        ASSIGN COMPONENT <lfs_find>-field OF STRUCTURE ls_reported-%element
               TO FIELD-SYMBOL(<lfs_elem>).
        IF sy-subrc = 0.
          <lfs_elem> = if_abap_behv=>mk-on.
        ENDIF.
      ENDIF.

      APPEND ls_reported TO ct_reported.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    TYPES:
      ty_item          TYPE STRUCTURE FOR READ RESULT zr_zari002\_Item,
      tt_item_failed   TYPE TABLE FOR FAILED LATE   zi_zari002_item,
      tt_item_reported TYPE TABLE FOR REPORTED LATE zi_zari002_item.

    METHODS setItemDefaults FOR DETERMINE ON SAVE
       keys FOR Item~setItemDefaults.

    METHODS validateArOpenItem FOR VALIDATE ON SAVE
       keys FOR Item~validateArOpenItem.

    METHODS validateCustomerCode FOR VALIDATE ON SAVE
       keys FOR Item~validateCustomerCode.

    METHODS validateItemMandatory FOR VALIDATE ON SAVE
       keys FOR Item~validateItemMandatory.

    METHODS validateSalesforceItemId FOR VALIDATE ON SAVE
       keys FOR Item~validateSalesforceItemId.

    "! แปลง finding จาก validator เป็น RAP message พร้อมชี้ field ที่ผิด
    METHODS report_item
      IMPORTING is_item     TYPE ty_item
                it_finding  TYPE zcl_zari002_validator=>tt_finding
      CHANGING  ct_failed   TYPE tt_item_failed
                ct_reported TYPE tt_item_reported.

ENDCLASS.

CLASS lhc_Item IMPLEMENTATION.

  METHOD setItemDefaults.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Item
        FIELDS ( CustomerCode )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    DATA lt_update TYPE TABLE FOR UPDATE zi_zari002_item.

    LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
      APPEND VALUE #( %tky         = <lfs_item>-%tky
                      CustomerCode = zcl_zari002_validator=>to_internal_key( <lfs_item>-CustomerCode ) )
             TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( CustomerCode )
        WITH lt_update.

  ENDMETHOD.

  METHOD validateArOpenItem.
  ENDMETHOD.

  METHOD validateCustomerCode.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    DATA lt_customer TYPE zif_zari002_master_data=>tt_customer.

    LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
      IF <lfs_item>-CustomerCode IS NOT INITIAL.
        INSERT <lfs_item>-CustomerCode INTO TABLE lt_customer.
      ENDIF.
    ENDLOOP.

    DATA(lt_unknown) = lhc_Payment=>master_data( )->find_unknown_customers( lt_customer ).

    LOOP AT lt_item ASSIGNING <lfs_item>.

      IF <lfs_item>-CustomerCode IS INITIAL
      OR NOT line_exists( lt_unknown[ table_line = <lfs_item>-CustomerCode ] ).
        CONTINUE.
      ENDIF.

      report_item(
        EXPORTING is_item     = <lfs_item>
                  it_finding  = VALUE #( ( msgno = '205'
                                           msgv1 = |{ <lfs_item>-SalesforceItemId }|
                                           msgv2 = |{ <lfs_item>-CustomerCode }|
                                           field = 'CustomerCode' ) )
        CHANGING  ct_failed   = failed-item
                  ct_reported = reported-item ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validateItemMandatory.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
      report_item(
        EXPORTING is_item     = <lfs_item>
                  it_finding  = zcl_zari002_validator=>check_item_mandatory( <lfs_item> )
        CHANGING  ct_failed   = failed-item
                  ct_reported = reported-item ).
    ENDLOOP.

  ENDMETHOD.

  METHOD validateSalesforceItemId.

    READ ENTITIES OF zr_zari002 IN LOCAL MODE
      ENTITY Item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    DATA lt_payment_uuid TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.

    LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
      INSERT <lfs_item>-PaymentUUID INTO TABLE lt_payment_uuid.
    ENDLOOP.

    LOOP AT lt_payment_uuid ASSIGNING FIELD-SYMBOL(<lfs_uuid>).

      DATA lt_group LIKE lt_item.
      CLEAR lt_group.

      LOOP AT lt_item ASSIGNING <lfs_item> WHERE PaymentUUID = <lfs_uuid>.
        APPEND <lfs_item> TO lt_group.
      ENDLOOP.

      DATA(lt_finding) = zcl_zari002_validator=>check_item_ids( lt_group ).

      LOOP AT lt_finding ASSIGNING FIELD-SYMBOL(<lfs_find>).

*       หา item ที่ finding พูดถึง เพื่อให้ message ชี้ไปที่บรรทัดนั้นจริง ๆ
        DATA lv_id  TYPE ztar_i002_item-salesforce_item_id.
        DATA lv_idx TYPE i.

        lv_id  = <lfs_find>-msgv1.
        lv_idx = line_index( lt_group[ SalesforceItemId = lv_id ] ).

        IF lv_idx = 0.
          lv_idx = 1.
        ENDIF.

        report_item(
          EXPORTING is_item     = lt_group[ lv_idx ]
                    it_finding  = VALUE #( ( <lfs_find> ) )
          CHANGING  ct_failed   = failed-item
                    ct_reported = reported-item ).

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

  METHOD report_item.

    IF it_finding IS INITIAL.
      RETURN.
    ENDIF.

    APPEND VALUE #( %tky = is_item-%tky ) TO ct_failed.

    LOOP AT it_finding ASSIGNING FIELD-SYMBOL(<lfs_find>).

      DATA ls_reported LIKE LINE OF ct_reported.
      CLEAR ls_reported.

      ls_reported-%tky = is_item-%tky.
      ls_reported-%msg = new_message( id       = 'ZARI002'
                                      number   = <lfs_find>-msgno
                                      severity = if_abap_behv_message=>severity-error
                                      v1       = <lfs_find>-msgv1
                                      v2       = <lfs_find>-msgv2 ).

      IF <lfs_find>-field IS NOT INITIAL.
        ASSIGN COMPONENT <lfs_find>-field OF STRUCTURE ls_reported-%element
               TO FIELD-SYMBOL(<lfs_elem>).
        IF sy-subrc = 0.
          <lfs_elem> = if_abap_behv=>mk-on.
        ENDIF.
      ENDIF.

      APPEND ls_reported TO ct_reported.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
