CLASS zcl_zari002_validator DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! RAP derived type ต้องผ่าน alias ก่อน ใช้ตรง ๆ ใน signature ไม่ได้
    TYPES:
      ty_payment TYPE STRUCTURE FOR READ RESULT zr_zari002,
      ty_item    TYPE STRUCTURE FOR READ RESULT zr_zari002\_Item,
      tt_item    TYPE TABLE FOR READ RESULT zr_zari002\_Item.

    TYPES:
      "! ผลการตรวจ 1 ข้อ — behavior pool แปลงเป็น RAP message ต่อ
      BEGIN OF ty_finding,
        msgno TYPE symsgno,
        msgv1 TYPE string,
        msgv2 TYPE string,
        field TYPE string,
      END OF ty_finding,
      tt_finding TYPE STANDARD TABLE OF ty_finding WITH EMPTY KEY.

    CONSTANTS:
      "! SAP payment method ที่หมายถึงเช็ค — ตัวตัดสิน conditional mandatory
      gc_pymt_method_cheque TYPE ztar_i002_pymt-sap_payment_method VALUE 'A'.

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
    CLASS-METHODS check_mandatory
      IMPORTING is_payment       TYPE ty_payment
      RETURNING VALUE(rt_result) TYPE tt_finding.

    "! 001 · 002 · ต้องมี item และจำนวนต้องตรงกับที่แจ้งมา
    CLASS-METHODS check_number_of_items
      IMPORTING iv_number_of_items TYPE ztar_i002_pymt-number_of_items_in_payment
                iv_item_count      TYPE i
      RETURNING VALUE(rt_result)   TYPE tt_finding.

    "! 003 · due_on ต้องไม่ก่อน issue_date
    CLASS-METHODS check_dates
      IMPORTING is_payment       TYPE ty_payment
      RETURNING VALUE(rt_result) TYPE tt_finding.

    "! 107–110 · field ที่บังคับเมื่อจ่ายด้วยเช็ค
    CLASS-METHODS check_cheque_fields
      IMPORTING is_payment       TYPE ty_payment
      RETURNING VALUE(rt_result) TYPE tt_finding.

    "! 011 · ผลรวม amount_paid ของทุก item ต้องมากกว่า 0
    CLASS-METHODS check_amount_paid_total
      IMPORTING iv_salesforce_id TYPE ztar_i002_pymt-salesforce_id
                it_item          TYPE tt_item
      RETURNING VALUE(rt_result) TYPE tt_finding.

    "! 111 · 005 · item id ต้องมี และห้ามซ้ำกันเองภายใน payment เดียวกัน
    CLASS-METHODS check_item_ids
      IMPORTING it_item          TYPE tt_item
      RETURNING VALUE(rt_result) TYPE tt_finding.

    "! 112–118 · 006 · field บังคับของ item + รูปแบบ partial flag
    CLASS-METHODS check_item_mandatory
      IMPORTING is_item          TYPE ty_item
      RETURNING VALUE(rt_result) TYPE tt_finding.

ENDCLASS.


CLASS zcl_zari002_validator IMPLEMENTATION.

  METHOD convert_payment_method.

*   mapping ชั่วคราว — รู้แค่ 2 คำที่ Salesforce ยืนยันแล้ว (OQ-02)
    rv_result = SWITCH #( to_upper( condense( CONV string( iv_payment_method ) ) )
                          WHEN 'CHEQUE'   THEN gc_pymt_method_cheque
                          WHEN 'TRANSFER' THEN 'T'
                          ELSE space ).

  ENDMETHOD.


  METHOD to_internal_key.

    DATA lv_key TYPE ztar_i002_pymt-gl_account.

    lv_key    = iv_value.
    rv_result = |{ lv_key ALPHA = IN }|.

  ENDMETHOD.


  METHOD check_mandatory.

    IF is_payment-SalesforceId IS INITIAL.
      APPEND VALUE #( msgno = '100' field = 'SalesforceId' ) TO rt_result.
    ENDIF.

    IF is_payment-PaymentDocumentNo IS INITIAL.
      APPEND VALUE #( msgno = '101' field = 'PaymentDocumentNo' ) TO rt_result.
    ENDIF.

    IF is_payment-CompanyCode IS INITIAL.
      APPEND VALUE #( msgno = '102' field = 'CompanyCode' ) TO rt_result.
    ENDIF.

    IF is_payment-PostingDate IS INITIAL.
      APPEND VALUE #( msgno = '103' field = 'PostingDate' ) TO rt_result.
    ENDIF.

    IF is_payment-GLAccount IS INITIAL.
      APPEND VALUE #( msgno = '104' field = 'GLAccount' ) TO rt_result.
    ENDIF.

    IF is_payment-PaymentMethod IS INITIAL.
      APPEND VALUE #( msgno = '105' field = 'PaymentMethod' ) TO rt_result.
    ENDIF.

    IF is_payment-PaymentAmount IS INITIAL.
      APPEND VALUE #( msgno = '106' field = 'PaymentAmount' ) TO rt_result.
    ENDIF.

  ENDMETHOD.


  METHOD check_number_of_items.

    IF iv_item_count = 0.
      APPEND VALUE #( msgno = '001' ) TO rt_result.
      RETURN.
    ENDIF.

    IF iv_number_of_items <> iv_item_count.
      APPEND VALUE #( msgno = '002'
                      msgv1 = |{ iv_number_of_items }|
                      msgv2 = |{ iv_item_count }|
                      field = 'NumberOfItems' ) TO rt_result.
    ENDIF.

  ENDMETHOD.


  METHOD check_dates.

*   เช็คเฉพาะเมื่อส่งมาทั้งคู่ — ความบังคับเป็นหน้าที่ check_cheque_fields
    IF is_payment-IssueDate IS NOT INITIAL
   AND is_payment-DueOn     IS NOT INITIAL
   AND is_payment-DueOn     < is_payment-IssueDate.

      APPEND VALUE #( msgno = '003'
                      msgv1 = |{ is_payment-DueOn DATE = ISO }|
                      msgv2 = |{ is_payment-IssueDate DATE = ISO }|
                      field = 'DueOn' ) TO rt_result.
    ENDIF.

  ENDMETHOD.


  METHOD check_cheque_fields.

    IF is_payment-SapPaymentMethod <> gc_pymt_method_cheque.
      RETURN.
    ENDIF.

    DATA(lv_method) = CONV string( is_payment-PaymentMethod ).

    IF is_payment-ChequeNo IS INITIAL.
      APPEND VALUE #( msgno = '107' msgv1 = lv_method field = 'ChequeNo' ) TO rt_result.
    ENDIF.

    IF is_payment-IssueDate IS INITIAL.
      APPEND VALUE #( msgno = '108' msgv1 = lv_method field = 'IssueDate' ) TO rt_result.
    ENDIF.

    IF is_payment-DueOn IS INITIAL.
      APPEND VALUE #( msgno = '109' msgv1 = lv_method field = 'DueOn' ) TO rt_result.
    ENDIF.

    IF is_payment-ChequeBankBranch IS INITIAL.
      APPEND VALUE #( msgno = '110' msgv1 = lv_method field = 'ChequeBankBranch' ) TO rt_result.
    ENDIF.

  ENDMETHOD.


  METHOD check_amount_paid_total.

    DATA lv_total TYPE ztar_i002_item-amount_paid.

    LOOP AT it_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
      lv_total = lv_total + <lfs_item>-AmountPaid.
    ENDLOOP.

    IF lv_total <= 0.
      APPEND VALUE #( msgno = '011'
                      msgv1 = |{ iv_salesforce_id }| ) TO rt_result.
    ENDIF.

  ENDMETHOD.


  METHOD check_item_ids.

    DATA lt_seen TYPE SORTED TABLE OF ztar_i002_item-salesforce_item_id
                      WITH UNIQUE KEY table_line.

    LOOP AT it_item ASSIGNING FIELD-SYMBOL(<lfs_item>).

      IF <lfs_item>-SalesforceItemId IS INITIAL.
*       ไม่มี id ให้อ้างถึง จึงออก message ที่ไม่ระบุรายการ แล้วข้ามการเช็คซ้ำ
        IF NOT line_exists( rt_result[ msgno = '111' ] ).
          APPEND VALUE #( msgno = '111' field = 'SalesforceItemId' ) TO rt_result.
        ENDIF.
        CONTINUE.
      ENDIF.

      INSERT <lfs_item>-SalesforceItemId INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        APPEND VALUE #( msgno = '005'
                        msgv1 = |{ <lfs_item>-SalesforceItemId }|
                        field = 'SalesforceItemId' ) TO rt_result.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD check_item_mandatory.

    DATA(lv_id) = CONV string( is_item-SalesforceItemId ).

    IF is_item-CustomerCode IS INITIAL.
      APPEND VALUE #( msgno = '112' msgv1 = lv_id field = 'CustomerCode' ) TO rt_result.
    ENDIF.

    IF is_item-AccountingDocument IS INITIAL.
      APPEND VALUE #( msgno = '113' msgv1 = lv_id field = 'AccountingDocument' ) TO rt_result.
    ENDIF.

    IF is_item-BillingDocument IS INITIAL.
      APPEND VALUE #( msgno = '114' msgv1 = lv_id field = 'BillingDocument' ) TO rt_result.
    ENDIF.

    IF is_item-InvoicePostingDate IS INITIAL.
      APPEND VALUE #( msgno = '115' msgv1 = lv_id field = 'InvoicePostingDate' ) TO rt_result.
    ENDIF.

    IF is_item-InvoiceAmount IS INITIAL.
      APPEND VALUE #( msgno = '116' msgv1 = lv_id field = 'InvoiceAmount' ) TO rt_result.
    ENDIF.

    IF is_item-AmountPaid IS INITIAL.
      APPEND VALUE #( msgno = '117' msgv1 = lv_id field = 'AmountPaid' ) TO rt_result.
    ENDIF.

    IF is_item-SaleSubmitDate IS INITIAL.
      APPEND VALUE #( msgno = '118' msgv1 = lv_id field = 'SaleSubmitDate' ) TO rt_result.
    ENDIF.

    IF is_item-PartialAmount IS NOT INITIAL AND is_item-PartialAmount <> 'X'.
      APPEND VALUE #( msgno = '006' msgv1 = lv_id field = 'PartialAmount' ) TO rt_result.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
