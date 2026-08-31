CLASS zcl_zari002_json DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      "! item ที่รับจาก JSON — date เป็น string เพราะ ISO ไม่ตรงกับ dats
      BEGIN OF ty_in_item,
        salesforce_item_id   TYPE ztar_i002_item-salesforce_item_id,
        customer_code        TYPE ztar_i002_item-customer_code,
        billing_note_no      TYPE ztar_i002_item-billing_note_no,
        accounting_document  TYPE ztar_i002_item-accounting_document,
        billing_document     TYPE ztar_i002_item-billing_document,
        invoice_posting_date TYPE string,
        invoice_amount       TYPE ztar_i002_item-invoice_amount,
        amount_paid          TYPE ztar_i002_item-amount_paid,
        partial_amount       TYPE ztar_i002_item-partial_amount,
        sale_submit_date     TYPE string,
      END OF ty_in_item,
      tt_in_item TYPE STANDARD TABLE OF ty_in_item WITH EMPTY KEY,

      BEGIN OF ty_in_payment,
        salesforce_id              TYPE ztar_i002_pymt-salesforce_id,
        payment_document_no        TYPE ztar_i002_pymt-payment_document_no,
        number_of_items_in_payment TYPE ztar_i002_pymt-number_of_items_in_payment,
        company_code               TYPE ztar_i002_pymt-company_code,
        posting_date               TYPE string,
        gl_account                 TYPE ztar_i002_pymt-gl_account,
        payment_method             TYPE ztar_i002_pymt-payment_method,
        cheque_no                  TYPE ztar_i002_pymt-cheque_no,
        issue_date                 TYPE string,
        due_on                     TYPE string,
        cheque_bank_branch         TYPE ztar_i002_pymt-cheque_bank_branch,
        rounding_diff              TYPE ztar_i002_pymt-rounding_diff,
        advance_payment            TYPE ztar_i002_pymt-advance_payment,
        fees                       TYPE ztar_i002_pymt-fees,
        payment_amount             TYPE ztar_i002_pymt-payment_amount,
        items                      TYPE tt_in_item,
      END OF ty_in_payment.

    "! แปลง JSON payload เป็น structure ของ table
    "! ชื่อ field แปลงอัตโนมัติด้วย pascal_case_to_underscore — ไม่มีตาราง mapping
    CLASS-METHODS parse
      IMPORTING iv_body    TYPE string
      EXPORTING es_payment TYPE ztar_i002_pymt
                et_item    TYPE zcl_zari002_validator=>tt_item
      RAISING   zcx_zari002_error.

    "! แปลงชื่อ field ของ table เป็นชื่อ JSON — ใช้ตอนสร้าง error response
    "! gl_account → GlAccount · salesforce_item_id → SalesforceItemId
    CLASS-METHODS to_json_name
      IMPORTING iv_field         TYPE string
      RETURNING VALUE(rv_result) TYPE string.

  PRIVATE SECTION.

    "! รับ ISO (2026-08-15) หรือ SAP (20260815) ก็ได้ · ค่าว่างคืนค่าว่าง
    CLASS-METHODS to_date
      IMPORTING iv_value         TYPE string
      RETURNING VALUE(rv_result) TYPE d.

ENDCLASS.


CLASS zcl_zari002_json IMPLEMENTATION.

  METHOD parse.

    CLEAR: es_payment, et_item.

    DATA ls_in TYPE ty_in_payment.

    TRY.
        xco_cp_json=>data->from_string( iv_body
          )->apply( VALUE #( ( xco_cp_json=>transformation->pascal_case_to_underscore ) )
          )->write_to( REF #( ls_in ) ).

      CATCH cx_root INTO DATA(lo_error).
        RAISE EXCEPTION TYPE zcx_zari002_error
          EXPORTING iv_msgv1 = |JSON parse failed: { lo_error->get_text( ) }|.
    ENDTRY.

*   ย้าย header — เว้น 3 field ที่เป็น string ไว้แปลงเอง
    es_payment = CORRESPONDING #( ls_in EXCEPT posting_date issue_date due_on ).

    es_payment-posting_date = to_date( ls_in-posting_date ).
    es_payment-issue_date   = to_date( ls_in-issue_date ).
    es_payment-due_on       = to_date( ls_in-due_on ).

    LOOP AT ls_in-items ASSIGNING FIELD-SYMBOL(<lfs_in>).

      APPEND CORRESPONDING ztar_i002_item( <lfs_in>
               EXCEPT invoice_posting_date sale_submit_date ) TO et_item
             ASSIGNING FIELD-SYMBOL(<lfs_item>).

      <lfs_item>-invoice_posting_date = to_date( <lfs_in>-invoice_posting_date ).
      <lfs_item>-sale_submit_date     = to_date( <lfs_in>-sale_submit_date ).

    ENDLOOP.

  ENDMETHOD.


  METHOD to_date.

    IF iv_value IS INITIAL.
      RETURN.
    ENDIF.

    rv_result = replace( val = iv_value sub = `-` with = `` occ = 0 ).

  ENDMETHOD.


  METHOD to_json_name.

    SPLIT to_lower( iv_field ) AT `_` INTO TABLE DATA(lt_part).

    LOOP AT lt_part ASSIGNING FIELD-SYMBOL(<lfs_part>).
      IF <lfs_part> IS INITIAL.
        CONTINUE.
      ENDIF.
      rv_result = |{ rv_result }| &&
                  |{ to_upper( substring( val = <lfs_part> len = 1 ) ) }| &&
                  |{ substring( val = <lfs_part> off = 1 ) }|.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
