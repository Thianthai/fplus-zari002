CLASS ltc_json DEFINITION FINAL
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    " ---- parse: โครงสร้าง ----
    METHODS parse_reads_request_id    FOR TESTING RAISING cx_static_check.
    METHODS parse_reads_two_payments  FOR TESTING RAISING cx_static_check.
    METHODS parse_maps_header         FOR TESTING RAISING cx_static_check.
    METHODS parse_reads_items         FOR TESTING RAISING cx_static_check.
    METHODS parse_second_payment      FOR TESTING RAISING cx_static_check.

    " ---- parse: วันที่ ----
    METHODS date_iso_dash             FOR TESTING RAISING cx_static_check.
    METHODS date_slash                FOR TESTING RAISING cx_static_check.
    METHODS date_dot                  FOR TESTING RAISING cx_static_check.
    METHODS date_already_internal     FOR TESTING RAISING cx_static_check.
    METHODS date_blank_stays_blank    FOR TESTING RAISING cx_static_check.
    METHODS item_dates_converted      FOR TESTING RAISING cx_static_check.

    " ---- parse: error ----
    METHODS broken_json_raises        FOR TESTING.

    " ---- to_json_name ----
    METHODS json_name_two_words       FOR TESTING.
    METHODS json_name_many_words      FOR TESTING.
    METHODS json_name_single_word     FOR TESTING.
    METHODS json_name_gl_account      FOR TESTING.

    " ---- helper ----
    "! payload 2 payment · ใบแรก 2 item · ใบที่สอง 1 item
    METHODS sample_json
      IMPORTING iv_posting_date  TYPE string DEFAULT `2026-08-15`
      RETURNING VALUE(rv_result) TYPE string.

    METHODS parse_sample
      IMPORTING iv_posting_date  TYPE string DEFAULT `2026-08-15`
      RETURNING VALUE(rs_result) TYPE zcl_zari002_json=>ty_request
      RAISING   cx_static_check.

    "! payment ใบแรก — เลี่ยงการต่อ [ ] ท้าย method call ซึ่ง ABAP ไม่รองรับ
    METHODS first_payment
      IMPORTING iv_posting_date  TYPE string DEFAULT `2026-08-15`
      RETURNING VALUE(rs_result) TYPE zcl_zari002_json=>ty_payment
      RAISING   cx_static_check.

ENDCLASS.


CLASS ltc_json IMPLEMENTATION.

  METHOD sample_json.

    rv_result =
      `{`                                                        &&
      `  "RequestId": "REQ-20260831-0001",`                      &&
      `  "Payments": [`                                          &&
      `    {`                                                    &&
      `      "SalesforceId": "SF0000000000000001",`              &&
      `      "PaymentDocumentNo": "1000000001",`                 &&
      `      "NumberOfItemsInPayment": 2,`                       &&
      `      "CompanyCode": "2000",`                             &&
      `      "PostingDate": "` && iv_posting_date && `",`        &&
      `      "GlAccount": "11011214",`                           &&
      `      "PaymentMethod": "Cheque",`                         &&
      `      "ChequeNo": "10020185",`                            &&
      `      "IssueDate": "2026-07-15",`                         &&
      `      "DueOn": "2026-08-31",`                             &&
      `      "ChequeBankBranch": "0040129",`                     &&
      `      "RoundingDiff": "0.00",`                            &&
      `      "AdvancePayment": "60.00",`                         &&
      `      "Fees": "5.00",`                                    &&
      `      "PaymentAmount": "9650.00",`                        &&
      `      "Items": [`                                         &&
      `        { "SalesforceItemId": "IT0000000000000001",`      &&
      `          "CustomerCode": "1000000002",`                  &&
      `          "BillingNoteNo": "BN00000001",`                 &&
      `          "AccountingDocument": "6000000001",`            &&
      `          "BillingDocument": "0090000000",`               &&
      `          "InvoicePostingDate": "2026-07-01",`            &&
      `          "InvoiceAmount": "1070.00",`                    &&
      `          "AmountPaid": "1070.00",`                       &&
      `          "PartialAmount": "",`                           &&
      `          "SaleSubmitDate": "2026-08-15" },`              &&
      `        { "SalesforceItemId": "IT0000000000000002",`      &&
      `          "CustomerCode": "1000000002",`                  &&
      `          "BillingNoteNo": "BN00000002",`                 &&
      `          "AccountingDocument": "6000000003",`            &&
      `          "BillingDocument": "0090000002",`               &&
      `          "InvoicePostingDate": "2026-08-03",`            &&
      `          "InvoiceAmount": "1605.00",`                    &&
      `          "AmountPaid": "500.00",`                        &&
      `          "PartialAmount": "X",`                          &&
      `          "SaleSubmitDate": "2026-08-15" }`               &&
      `      ]`                                                  &&
      `    },`                                                   &&
      `    {`                                                    &&
      `      "SalesforceId": "SF0000000000000002",`              &&
      `      "PaymentDocumentNo": "1000000002",`                 &&
      `      "NumberOfItemsInPayment": 1,`                       &&
      `      "CompanyCode": "2000",`                             &&
      `      "PostingDate": "2026-08-16",`                       &&
      `      "GlAccount": "11011211",`                           &&
      `      "PaymentMethod": "Transfer",`                       &&
      `      "PaymentAmount": "500.00",`                         &&
      `      "Items": [`                                         &&
      `        { "SalesforceItemId": "IT0000000000000003",`      &&
      `          "CustomerCode": "1000000003",`                  &&
      `          "AccountingDocument": "6000000009",`            &&
      `          "BillingDocument": "0090000009",`               &&
      `          "InvoicePostingDate": "2026-08-01",`            &&
      `          "InvoiceAmount": "500.00",`                     &&
      `          "AmountPaid": "500.00",`                        &&
      `          "SaleSubmitDate": "2026-08-16" }`               &&
      `      ]`                                                  &&
      `    }`                                                    &&
      `  ]`                                                      &&
      `}`.

  ENDMETHOD.


  METHOD parse_sample.
    zcl_zari002_json=>parse_json_request(
      EXPORTING iv_body    = sample_json( iv_posting_date )
      IMPORTING es_request = rs_result ).
  ENDMETHOD.


  METHOD first_payment.
    DATA(ls_request) = parse_sample( iv_posting_date ).
    rs_result = ls_request-payments[ 1 ].
  ENDMETHOD.


* =====================================================================
* โครงสร้าง
* =====================================================================

  METHOD parse_reads_request_id.
    cl_abap_unit_assert=>assert_equals(
      exp = 'REQ-20260831-0001'
      act = parse_sample( )-request_id ).
  ENDMETHOD.


  METHOD parse_reads_two_payments.
    cl_abap_unit_assert=>assert_equals(
      exp = 2
      act = lines( parse_sample( )-payments )
      msg = '1 request รับได้หลาย payment' ).
  ENDMETHOD.


  METHOD parse_maps_header.

    DATA(ls_payment) = first_payment( ).

    cl_abap_unit_assert=>assert_equals( exp = 'SF0000000000000001' act = ls_payment-salesforce_id ).
    cl_abap_unit_assert=>assert_equals( exp = '1000000001'         act = ls_payment-payment_document_no ).
    cl_abap_unit_assert=>assert_equals( exp = 2                    act = ls_payment-number_of_items_in_payment ).
    cl_abap_unit_assert=>assert_equals( exp = '2000'               act = ls_payment-company_code ).
    cl_abap_unit_assert=>assert_equals( exp = 'Cheque'             act = ls_payment-payment_method ).
    cl_abap_unit_assert=>assert_equals( exp = '10020185'           act = ls_payment-cheque_no ).
    cl_abap_unit_assert=>assert_equals( exp = '0040129'            act = ls_payment-cheque_bank_branch ).
    cl_abap_unit_assert=>assert_equals( exp = '9650.00'            act = ls_payment-payment_amount ).
    cl_abap_unit_assert=>assert_equals( exp = '60.00'              act = ls_payment-advance_payment ).

*   ยังไม่ pad ตรงนี้ — เป็นหน้าที่ของ processor ตอน normalize
    cl_abap_unit_assert=>assert_equals(
      exp = '11011214'
      act = ls_payment-gl_account
      msg = 'GlAccount ต้องแปลงชื่อได้ — ตัวที่เคยพังตอนชื่อ GLAccount' ).

  ENDMETHOD.


  METHOD parse_reads_items.

    DATA(lt_item) = first_payment( )-items.

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt_item ) ).

    cl_abap_unit_assert=>assert_equals( exp = 'IT0000000000000001' act = lt_item[ 1 ]-salesforce_item_id ).
    cl_abap_unit_assert=>assert_equals( exp = '0090000000'         act = lt_item[ 1 ]-billing_document ).
    cl_abap_unit_assert=>assert_equals( exp = '1070.00'            act = lt_item[ 1 ]-amount_paid ).
    cl_abap_unit_assert=>assert_initial( act = lt_item[ 1 ]-partial_amount ).

    cl_abap_unit_assert=>assert_equals( exp = '500.00' act = lt_item[ 2 ]-amount_paid ).
    cl_abap_unit_assert=>assert_equals( exp = 'X'      act = lt_item[ 2 ]-partial_amount ).

  ENDMETHOD.


  METHOD parse_second_payment.

    DATA(ls_request) = parse_sample( ).
    DATA(ls_payment) = ls_request-payments[ 2 ].

    cl_abap_unit_assert=>assert_equals( exp = 'SF0000000000000002' act = ls_payment-salesforce_id ).
    cl_abap_unit_assert=>assert_equals( exp = 'Transfer'           act = ls_payment-payment_method ).
    cl_abap_unit_assert=>assert_equals( exp = 1                    act = lines( ls_payment-items ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'IT0000000000000003'
                                        act = ls_payment-items[ 1 ]-salesforce_item_id ).

*   ใบนี้ไม่ได้ส่ง field ของเช็คมา ต้องว่างไม่ใช่ค่าของใบก่อนหน้า
    cl_abap_unit_assert=>assert_initial(
      act = ls_payment-cheque_no
      msg = 'field ที่ไม่ได้ส่งมาต้องว่าง ไม่ใช่ค่าตกค้างจาก payment ใบก่อน' ).

  ENDMETHOD.

* =====================================================================
* วันที่ — ทุกรูปแบบต้องได้ YYYYMMDD เหมือนกัน
* =====================================================================

  METHOD date_iso_dash.
    cl_abap_unit_assert=>assert_equals(
      exp = '20260815'
      act = first_payment( `2026-08-15` )-posting_date ).
  ENDMETHOD.

  METHOD date_slash.
    cl_abap_unit_assert=>assert_equals(
      exp = '20260815'
      act = first_payment( `2026/08/15` )-posting_date ).
  ENDMETHOD.

  METHOD date_dot.
    cl_abap_unit_assert=>assert_equals(
      exp = '20260815'
      act = first_payment( `2026.08.15` )-posting_date ).
  ENDMETHOD.

  METHOD date_already_internal.
    cl_abap_unit_assert=>assert_equals(
      exp = '20260815'
      act = first_payment( `20260815` )-posting_date
      msg = 'ส่งมาแบบ SAP อยู่แล้วต้องได้ผลเดียวกัน' ).
  ENDMETHOD.

  METHOD date_blank_stays_blank.
    cl_abap_unit_assert=>assert_initial(
      act = first_payment( `` )-posting_date
      msg = 'ค่าว่างต้องยังว่าง ให้ mandatory check เป็นคนจับ' ).
  ENDMETHOD.

  METHOD item_dates_converted.

    DATA(lt_item) = first_payment( )-items.

    cl_abap_unit_assert=>assert_equals( exp = '20260701' act = lt_item[ 1 ]-invoice_posting_date ).
    cl_abap_unit_assert=>assert_equals( exp = '20260815' act = lt_item[ 1 ]-sale_submit_date ).
    cl_abap_unit_assert=>assert_equals( exp = '20260803' act = lt_item[ 2 ]-invoice_posting_date ).

  ENDMETHOD.

* =====================================================================
* error
* =====================================================================

  METHOD broken_json_raises.

    TRY.
        zcl_zari002_json=>parse_json_request(
          EXPORTING iv_body    = `{ "RequestId": `
          IMPORTING es_request = DATA(ls_request) ).

        cl_abap_unit_assert=>fail( 'JSON พังต้อง raise ไม่ใช่ผ่านเงียบ ๆ' ).

      CATCH zcx_zari002_error.
        " ถูกต้อง
    ENDTRY.

  ENDMETHOD.

* =====================================================================
* to_json_name
* =====================================================================

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
      msg = 'ต้องตรงกับที่ parser คาดไว้ ไม่งั้น 2 ทางไม่ตรงกัน' ).
  ENDMETHOD.

ENDCLASS.
