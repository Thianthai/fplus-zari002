CLASS lhc_Payment DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PUBLIC SECTION.

    "! ให้ unit test ใส่ test double แทน implementation จริงได้
    CLASS-METHODS set_md_check
      IMPORTING io_md_check TYPE REF TO zif_zari002_md_chk.

  PRIVATE SECTION.

    CLASS-DATA go_md_check TYPE REF TO zif_zari002_md_chk.

    "! คืน md check ตัวที่ใช้อยู่ สร้าง implementation จริงถ้ายังไม่มีใครใส่ไว้
    CLASS-METHODS md_check
      RETURNING VALUE(ro_result) TYPE REF TO zif_zari002_md_chk.

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

ENDCLASS.

CLASS lhc_Payment IMPLEMENTATION.

  METHOD set_md_check.
    go_md_check = io_md_check.
  ENDMETHOD.

  METHOD md_check.
    IF go_md_check IS NOT BOUND.
      go_md_check = NEW zcl_zari002_md_check( ).
    ENDIF.
    ro_result = go_md_check.
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
    DATA lt_company_code TYPE zif_zari002_md_chk=>tt_company_code.

    LOOP AT lt_payment ASSIGNING FIELD-SYMBOL(<lfs_pay>).
      INSERT <lfs_pay>-CompanyCode INTO TABLE lt_company_code.
    ENDLOOP.

    DATA(lt_cc_info) = md_check( )->get_company_codes( lt_company_code ).

*   จำ currency ของแต่ละ payment ไว้ เพื่อส่งต่อให้ item ท้าย method
    TYPES: BEGIN OF ty_currency_of,
             payment_uuid TYPE sysuuid_x16,
             currency     TYPE zif_zari002_md_chk=>ty_currency,
           END OF ty_currency_of.

    DATA lt_currency_of TYPE SORTED TABLE OF ty_currency_of
                             WITH UNIQUE KEY payment_uuid.

    DATA lt_update TYPE TABLE FOR UPDATE zr_zari002.

    LOOP AT lt_payment ASSIGNING <lfs_pay>.

      DATA(lv_currency) = COND zif_zari002_md_chk=>ty_currency(
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
  ENDMETHOD.

  METHOD validateChequeBankBranch.
  ENDMETHOD.

  METHOD validateChequeFields.
  ENDMETHOD.

  METHOD validateCompanyCode.
  ENDMETHOD.

  METHOD validateDates.
  ENDMETHOD.

  METHOD validateGLAccount.
  ENDMETHOD.

  METHOD validateItemDuplicate.
  ENDMETHOD.

  METHOD validateMandatory.
  ENDMETHOD.

  METHOD validateNumberOfItems.
  ENDMETHOD.

  METHOD validatePaymentMethod.
  ENDMETHOD.

  METHOD validatePaymentTotal.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

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
  ENDMETHOD.

  METHOD validateItemMandatory.
  ENDMETHOD.

  METHOD validateSalesforceItemId.
  ENDMETHOD.

ENDCLASS.
