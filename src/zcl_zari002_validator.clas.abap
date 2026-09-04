CLASS zcl_zari002_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      ty_payment TYPE ztar_i002_pymt,
      ty_item    TYPE ztar_i002_item,
      tt_item    TYPE STANDARD TABLE OF ztar_i002_item WITH EMPTY KEY.

    TYPES:
      "! ผลการตรวจ 1 ข้อ — ผู้เรียกแปลงเป็น message ต่อ
      BEGIN OF ty_finding,
        msgno TYPE symsgno,
        msgv1 TYPE string,
        msgv2 TYPE string,
        msgv3 TYPE string,
        msgv4 TYPE string,
        field TYPE string,
      END OF ty_finding,
      tt_finding TYPE STANDARD TABLE OF ty_finding WITH EMPTY KEY.

    CONSTANTS:
      "! SAP payment method ที่หมายถึงเช็ค — ตัวตัดสิน conditional mandatory
      gc_pymt_method_cheque   TYPE ztar_i002_pymt-sap_payment_method VALUE 'A',
      gc_pymt_method_transfer TYPE ztar_i002_pymt-sap_payment_method VALUE 'T'.

    "! แปลงคำจาก Salesforce เป็น SAP payment method code
    "! คืนค่าว่างถ้าไม่รู้จักคำนั้น — ผู้เรียกออก message 202
    "! ⚠️ mapping อยู่ที่นี่ที่เดียว ย้ายไป constant table ทีหลังแก้แค่ method นี้ (OQ-02)
    CLASS-METHODS convert_payment_method
      IMPORTING iv_payment_method TYPE ztar_i002_pymt-payment_method
      RETURNING VALUE(rv_result)  TYPE ztar_i002_pymt-sap_payment_method.

    "! เติม 0 ข้างหน้าให้ครบ 10 หลัก — ใช้กับ gl_account และ customer_code
    "! ค่าที่ pad มาแล้วส่งเข้ามาซ้ำได้ ผลลัพธ์เท่าเดิม
    CLASS-METHODS to_internal_key
      IMPORTING iv_value         TYPE clike
      RETURNING VALUE(rv_result) TYPE ztar_i002_pymt-gl_account.

    "! 100–106 · field บังคับของ header
    CLASS-METHODS check_payment_mandatory
      IMPORTING is_payment        TYPE ty_payment
      RETURNING VALUE(rt_finding) TYPE tt_finding.

    "! 001 · 002 · ต้องมี item และจำนวนต้องตรงกับที่แจ้งมา
    CLASS-METHODS check_number_of_items
      IMPORTING iv_number_of_items TYPE ztar_i002_pymt-number_of_items_in_payment
                iv_item_count      TYPE i
      RETURNING VALUE(rt_finding)  TYPE tt_finding.

    "! 003 · due_on ต้องไม่ก่อน issue_date
    CLASS-METHODS check_dates
      IMPORTING is_payment        TYPE ty_payment
      RETURNING VALUE(rt_finding) TYPE tt_finding.

    "! 107–110 · field ที่บังคับเมื่อจ่ายด้วยเช็ค
    CLASS-METHODS check_cheque_fields
      IMPORTING is_payment        TYPE ty_payment
      RETURNING VALUE(rt_finding) TYPE tt_finding.

    "! 011 · ผลรวม amount_paid ของทุก item ต้องมากกว่า 0
    CLASS-METHODS check_amount_paid_total
      IMPORTING iv_salesforce_id  TYPE ztar_i002_pymt-salesforce_id
                it_item           TYPE tt_item
      RETURNING VALUE(rt_finding) TYPE tt_finding.

    "! 111 · 005 · item id ต้องมี และห้ามซ้ำกันเองภายใน payment เดียวกัน
    CLASS-METHODS check_item_ids
      IMPORTING it_item           TYPE tt_item
      RETURNING VALUE(rt_finding) TYPE tt_finding.

    "! 112–118 · 006 · field บังคับของ item + รูปแบบ partial flag
    CLASS-METHODS check_item_mandatory
      IMPORTING is_item           TYPE ty_item
      RETURNING VALUE(rt_finding) TYPE tt_finding.

ENDCLASS.



CLASS zcl_zari002_validator IMPLEMENTATION.

  METHOD convert_payment_method.

*   mapping ชั่วคราว — รู้แค่ 2 คำที่ Salesforce ยืนยันแล้ว (OQ-02)
    rv_result = SWITCH #( to_upper( condense( CONV string( iv_payment_method ) ) )
                          WHEN 'CHEQUE'   THEN gc_pymt_method_cheque
                          WHEN 'TRANSFER' THEN gc_pymt_method_transfer
                          ELSE space ).

  ENDMETHOD.


  METHOD to_internal_key.

    DATA lv_key TYPE ztar_i002_pymt-gl_account.

    lv_key    = iv_value.
    rv_result = |{ lv_key ALPHA = IN }|.

  ENDMETHOD.


  METHOD check_payment_mandatory.

    IF is_payment-salesforce_id IS INITIAL.
      APPEND VALUE #( msgno = '100'
                      field = 'salesforce_id'
                   ) TO rt_finding.
    ENDIF.

    IF is_payment-payment_document_no IS INITIAL.
      APPEND VALUE #( msgno = '101'
                      field = 'payment_document_no'
                    ) TO rt_finding.
    ENDIF.

    IF is_payment-company_code IS INITIAL.
      APPEND VALUE #( msgno = '102'
                      field = 'company_code'
                    ) TO rt_finding.
    ENDIF.

    IF is_payment-posting_date IS INITIAL.
      APPEND VALUE #( msgno = '103'
                      field = 'posting_date'
                    ) TO rt_finding.
    ENDIF.

    IF is_payment-gl_account IS INITIAL.
      APPEND VALUE #( msgno = '104'
                      field = 'gl_account'
                    ) TO rt_finding.
    ENDIF.

    IF is_payment-payment_method IS INITIAL.
      APPEND VALUE #( msgno = '105'
                      field = 'payment_method'
                    ) TO rt_finding.
    ENDIF.

    IF is_payment-payment_amount IS INITIAL.
      APPEND VALUE #( msgno = '106'
                      field = 'payment_amount'
                    ) TO rt_finding.
    ENDIF.

  ENDMETHOD.


  METHOD check_number_of_items.

    IF iv_item_count = 0.
      APPEND VALUE #( msgno = '001' ) TO rt_finding.
      RETURN.
    ENDIF.

    IF iv_number_of_items <> iv_item_count.
      APPEND VALUE #( msgno = '002'
                      msgv1 = |{ iv_number_of_items }|
                      msgv2 = |{ iv_item_count }|
                      field = 'number_of_items_in_payment'
                    ) TO rt_finding.
    ENDIF.

  ENDMETHOD.


  METHOD check_dates.

    IF is_payment-issue_date IS NOT INITIAL
    AND is_payment-due_on IS NOT INITIAL
    AND is_payment-due_on < is_payment-issue_date.

      APPEND VALUE #( msgno = '003'
                      msgv1 = |{ is_payment-due_on DATE = ISO }|
                      msgv2 = |{ is_payment-issue_date DATE = ISO }|
                      field = 'due_on'
                    ) TO rt_finding.
    ENDIF.

  ENDMETHOD.


  METHOD check_cheque_fields.

    IF is_payment-sap_payment_method <> gc_pymt_method_cheque.
      RETURN.
    ENDIF.

    DATA(lv_method) = CONV string( is_payment-payment_method ).

    IF is_payment-cheque_no IS INITIAL.
      APPEND VALUE #( msgno = '107'
                      msgv1 = lv_method
                      field = 'cheque_no'
                    ) TO rt_finding.
    ENDIF.

    IF is_payment-issue_date IS INITIAL.
      APPEND VALUE #( msgno = '108'
                      msgv1 = lv_method
                      field = 'issue_date'
                    ) TO rt_finding.
    ENDIF.

    IF is_payment-due_on IS INITIAL.
      APPEND VALUE #( msgno = '109'
                      msgv1 = lv_method
                      field = 'due_on'
                    ) TO rt_finding.
    ENDIF.

    IF is_payment-cheque_bank_branch IS INITIAL.
      APPEND VALUE #( msgno = '110'
                      msgv1 = lv_method
                      field = 'cheque_bank_branch'
                    ) TO rt_finding.
    ENDIF.

  ENDMETHOD.


  METHOD check_amount_paid_total.

    DATA lv_total TYPE ztar_i002_item-amount_paid.

    LOOP AT it_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
      lv_total = lv_total + <lfs_item>-amount_paid.
    ENDLOOP.

    IF lv_total <= 0.
      APPEND VALUE #( msgno = '011'
                      msgv1 = |{ iv_salesforce_id }|
                    ) TO rt_finding.
    ENDIF.

  ENDMETHOD.


  METHOD check_item_ids.

    DATA lt_seen TYPE SORTED TABLE OF ztar_i002_item-salesforce_item_id
                 WITH UNIQUE KEY table_line.

    LOOP AT it_item ASSIGNING FIELD-SYMBOL(<lfs_item>).

      IF <lfs_item>-salesforce_item_id IS INITIAL.
*       ไม่มี id ให้อ้างถึง จึงออก message ที่ไม่ระบุรายการ แล้วข้ามการเช็คซ้ำ
        IF NOT line_exists( rt_finding[ msgno = '111' ] ).
          APPEND VALUE #( msgno = '111'
                          field = 'salesforce_item_id'
                        ) TO rt_finding.
        ENDIF.
        CONTINUE.
      ENDIF.

      INSERT <lfs_item>-salesforce_item_id INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        APPEND VALUE #( msgno = '005'
                        msgv1 = |{ <lfs_item>-salesforce_item_id }|
                        field = 'salesforce_item_id'
                      ) TO rt_finding.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD check_item_mandatory.

    IF is_item-customer_code IS INITIAL.
      APPEND VALUE #( msgno = '112'
                      field = 'customer_code'
                    ) TO rt_finding.
    ENDIF.

    IF is_item-accounting_document IS INITIAL.
      APPEND VALUE #( msgno = '113'
                      field = 'accounting_document'
                    ) TO rt_finding.
    ENDIF.

    IF is_item-billing_document IS INITIAL.
      APPEND VALUE #( msgno = '114'
                      field = 'billing_document'
                    ) TO rt_finding.
    ENDIF.

    IF is_item-invoice_posting_date IS INITIAL.
      APPEND VALUE #( msgno = '115'
                      field = 'invoice_posting_date'
                    ) TO rt_finding.
    ENDIF.

    IF is_item-invoice_amount IS INITIAL.
      APPEND VALUE #( msgno = '116'
                      field = 'invoice_amount'
                    ) TO rt_finding.
    ENDIF.

    IF is_item-amount_paid IS INITIAL.
      APPEND VALUE #( msgno = '117'
                      field = 'amount_paid'
                    ) TO rt_finding.
    ENDIF.

    IF is_item-sale_submit_date IS INITIAL.
      APPEND VALUE #( msgno = '118'
                      field = 'sale_submit_date'
                    ) TO rt_finding.
    ENDIF.

    IF is_item-partial_amount IS NOT INITIAL AND is_item-partial_amount <> 'X'.
      APPEND VALUE #( msgno = '006'
                      field = 'partial_amount'
                    ) TO rt_finding.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
