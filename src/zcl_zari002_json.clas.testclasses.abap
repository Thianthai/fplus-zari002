CLASS ltc_json DEFINITION FINAL
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    METHODS parse_maps_header       FOR TESTING RAISING cx_static_check.
    METHODS parse_converts_iso_date FOR TESTING RAISING cx_static_check.
    METHODS parse_accepts_sap_date  FOR TESTING RAISING cx_static_check.
    METHODS parse_reads_items       FOR TESTING RAISING cx_static_check.
    METHODS broken_json_raises      FOR TESTING.

    METHODS json_name_two_words     FOR TESTING.
    METHODS json_name_many_words    FOR TESTING.
    METHODS json_name_single_word   FOR TESTING.
    METHODS json_name_gl_account    FOR TESTING.

    "! payload ตัวอย่าง 1 header + 2 item
    METHODS sample_json
      IMPORTING iv_posting_date  TYPE string DEFAULT `2026-08-15`
      RETURNING VALUE(rv_result) TYPE string.

ENDCLASS.


CLASS ltc_json IMPLEMENTATION.

  METHOD sample_json.

    rv_result =
      `{`                                                     &&
      `  "SalesforceId": "SF0000000000000001",`               &&
      `  "PaymentDocumentNo": "1000000001",`                  &&
      `  "NumberOfItemsInPayment": 2,`                        &&
      `  "CompanyCode": "2000",`                              &&
      `  "PostingDate": "` && iv_posting_date && `",`         &&
      `  "GlAccount": "11011214",`                            &&
      `  "PaymentMethod": "Cheque",`                          &&
      `  "ChequeNo": "10020185",`                             &&
      `  "IssueDate": "2026-07-15",`                          &&
      `  "DueOn": "2026-08-31",`                              &&
      `  "ChequeBankBranch": "0040129",`                      &&
      `  "RoundingDiff": "0.00",`                             &&
      `  "AdvancePayment": "60.00",`                          &&
      `  "Fees": "5.00",`                                     &&
      `  "PaymentAmount": "9650.00",`                         &&
      `  "Items": [`                                          &&
      `    {`                                                 &&
      `      "SalesforceItemId": "IT0000000000000001",`       &&
      `      "CustomerCode": "1000000002",`                   &&
      `      "BillingNoteNo": "BN00000001",`                  &&
      `      "AccountingDocument": "6000000001",`             &&
      `      "BillingDocument": "0090000000",`                &&
      `      "InvoicePostingDate": "2026-07-01",`             &&
      `      "InvoiceAmount": "1070.00",`                     &&
      `      "AmountPaid": "1070.00",`                        &&
      `      "PartialAmount": "",`                            &&
      `      "SaleSubmitDate": "2026-08-15"`                  &&
      `    },`                                                &&
      `    {`                                                 &&
      `      "SalesforceItemId": "IT0000000000000002",`       &&
      `      "CustomerCode": "1000000002",`                   &&
      `      "BillingNoteNo": "BN00000002",`                  &&
      `      "AccountingDocument": "6000000003",`             &&
      `      "BillingDocument": "0090000002",`                &&
      `      "InvoicePostingDate": "2026-08-03",`             &&
      `      "InvoiceAmount": "1605.00",`                     &&
      `      "AmountPaid": "500.00",`                         &&
      `      "PartialAmount": "X",`                           &&
      `      "SaleSubmitDate": "2026-08-15"`                  &&
      `    }`                                                 &&
      `  ]`                                                   &&
      `}`.

  ENDMETHOD.


  METHOD parse_maps_header.

    zcl_zari002_json=>parse( EXPORTING iv_body    = sample_json( )
                             IMPORTING es_payment = DATA(ls_payment)
                                       et_item    = DATA(lt_item) ).

    cl_abap_unit_assert=>assert_equals( exp = 'SF0000000000000001' act = ls_payment-salesforce_id ).
    cl_abap_unit_assert=>assert_equals( exp = '1000000001'         act = ls_payment-payment_document_no ).
    cl_abap_unit_assert=>assert_equals( exp = 2                    act = ls_payment-number_of_items_in_payment ).
    cl_abap_unit_assert=>assert_equals( exp = '2000'               act = ls_payment-company_code ).
    cl_abap_unit_assert=>assert_equals( exp = 'Cheque'             act = ls_payment-payment_method ).
    cl_abap_unit_assert=>assert_equals( exp = '0040129'            act = ls_payment-cheque_bank_branch ).

*   ยังไม่ pad ตรงนี้ — เป็นหน้าที่ของ processor ตอน normalize
    cl_abap_unit_assert=>assert_equals(
      exp = '11011214'
      act = ls_payment-gl_account
      msg = 'GlAccount ต้องแปลงชื่อได้ถูก — ตัวที่เคยพังตอนชื่อ GLAccount' ).

    cl_abap_unit_assert=>assert_equals( exp = '9650.00' act = ls_payment-payment_amount ).
    cl_abap_unit_assert=>assert_equals( exp = '60.00'   act = ls_payment-advance_payment ).

  ENDMETHOD.


  METHOD parse_converts_iso_date.

    zcl_zari002_json=>parse( EXPORTING iv_body    = sample_json( )
                             IMPORTING es_payment = DATA(ls_payment)
                                       et_item    = DATA(lt_item) ).

    cl_abap_unit_assert=>assert_equals( exp = '20260815' act = ls_payment-posting_date ).
    cl_abap_unit_assert=>assert_equals( exp = '20260715' act = ls_payment-issue_date ).
    cl_abap_unit_assert=>assert_equals( exp = '20260831' act = ls_payment-due_on ).

  ENDMETHOD.


  METHOD parse_accepts_sap_date.

    zcl_zari002_json=>parse( EXPORTING iv_body    = sample_json( `20260815` )
                             IMPORTING es_payment = DATA(ls_payment)
                                       et_item    = DATA(lt_item) ).

    cl_abap_unit_assert=>assert_equals(
      exp = '20260815'
      act = ls_payment-posting_date
      msg = 'ส่งมาแบบ SAP ก็ต้องได้ผลเดียวกับ ISO' ).

  ENDMETHOD.


  METHOD parse_reads_items.

    zcl_zari002_json=>parse( EXPORTING iv_body    = sample_json( )
                             IMPORTING es_payment = DATA(ls_payment)
                                       et_item    = DATA(lt_item) ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt_item ) ).

    cl_abap_unit_assert=>assert_equals( exp = 'IT0000000000000001' act = lt_item[ 1 ]-salesforce_item_id ).
    cl_abap_unit_assert=>assert_equals( exp = '0090000000'         act = lt_item[ 1 ]-billing_document ).
    cl_abap_unit_assert=>assert_equals( exp = '1070.00'            act = lt_item[ 1 ]-amount_paid ).
    cl_abap_unit_assert=>assert_equals( exp = '20260701'           act = lt_item[ 1 ]-invoice_posting_date ).
    cl_abap_unit_assert=>assert_initial( act = lt_item[ 1 ]-partial_amount ).

    cl_abap_unit_assert=>assert_equals( exp = 'IT0000000000000002' act = lt_item[ 2 ]-salesforce_item_id ).
    cl_abap_unit_assert=>assert_equals( exp = '500.00'             act = lt_item[ 2 ]-amount_paid ).
    cl_abap_unit_assert=>assert_equals( exp = 'X'                  act = lt_item[ 2 ]-partial_amount ).

  ENDMETHOD.


  METHOD broken_json_raises.

    TRY.
        zcl_zari002_json=>parse( EXPORTING iv_body    = `{ "SalesforceId": `
                                 IMPORTING es_payment = DATA(ls_payment)
                                           et_item    = DATA(lt_item) ).

        cl_abap_unit_assert=>fail( 'JSON พังต้อง raise exception ไม่ใช่ผ่านเงียบ ๆ' ).

      CATCH zcx_zari002_error.
        " ถูกต้อง
    ENDTRY.

  ENDMETHOD.


  METHOD json_name_two_words.
    cl_abap_unit_assert=>assert_equals(
      exp = 'AmountPaid'
      act = zcl_zari002_json=>to_json_name( 'amount_paid' ) ).
  ENDMETHOD.

  METHOD json_name_many_words.
    cl_abap_unit_assert=>assert_equals(
      exp = 'NumberOfItemsInPayment'
      act = zcl_zari002_json=>to_json_name( 'number_of_items_in_payment' ) ).
  ENDMETHOD.

  METHOD json_name_single_word.
    cl_abap_unit_assert=>assert_equals(
      exp = 'Fees'
      act = zcl_zari002_json=>to_json_name( 'fees' ) ).
  ENDMETHOD.

  METHOD json_name_gl_account.
    cl_abap_unit_assert=>assert_equals(
      exp = 'GlAccount'
      act = zcl_zari002_json=>to_json_name( 'gl_account' )
      msg = 'ต้องตรงกับที่ parser คาดไว้ ไม่งั้น 2 ทางจะไม่ตรงกัน' ).
  ENDMETHOD.

ENDCLASS.
