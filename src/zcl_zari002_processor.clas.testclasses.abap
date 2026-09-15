CLASS ltd_master_data DEFINITION FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_zari002_master_data.
ENDCLASS.

CLASS ltd_master_data IMPLEMENTATION.

  METHOD zif_zari002_master_data~get_company_codes.
    LOOP AT it_company_code ASSIGNING FIELD-SYMBOL(<lfs_cc>).
      IF <lfs_cc> = '2000'.
        INSERT VALUE #( company_code = '2000' currency = 'THB' country = 'TH' ) INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_zari002_master_data~find_unknown_gl_accounts.
    LOOP AT it_gl_key ASSIGNING FIELD-SYMBOL(<lfs_k>).
      IF <lfs_k>-company_code <> '2000' OR <lfs_k>-gl_account <> '0011011214'.
        INSERT <lfs_k> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_zari002_master_data~find_unknown_pymt_methods.
    LOOP AT it_payment_method_key ASSIGNING FIELD-SYMBOL(<lfs_k>).
      IF NOT ( <lfs_k>-country = 'TH'
               AND ( <lfs_k>-payment_method = 'A' OR <lfs_k>-payment_method = 'T' ) ).
        INSERT <lfs_k> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_zari002_master_data~find_unknown_banks.
    LOOP AT it_bank_key ASSIGNING FIELD-SYMBOL(<lfs_b>).
      IF NOT ( <lfs_b>-country = 'TH' AND <lfs_b>-bank = '0040129' ).
        INSERT <lfs_b> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_zari002_master_data~find_unknown_customers.
    LOOP AT it_customer ASSIGNING FIELD-SYMBOL(<lfs_c>).
      IF <lfs_c> <> '1000000002'.
        INSERT <lfs_c> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS ltd_notify DEFINITION FOR TESTING INHERITING FROM zcl_zari003_sfdc_notify.
  PUBLIC SECTION.
    "! เก็บสิ่งที่ "จะยิง" ไว้ตรวจ แทนที่จะยิงจริง
    DATA gt_sent TYPE zcl_zari003_sfdc_notify=>tt_result.
    METHODS notify REDEFINITION.
ENDCLASS.

CLASS ltd_notify IMPLEMENTATION.
  METHOD notify.
    gt_sent = it_result.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_processor DEFINITION FINAL
  FOR TESTING
  DURATION SHORT
  RISK LEVEL DANGEROUS.

  PRIVATE SECTION.

    CLASS-DATA go_osql TYPE REF TO if_osql_test_environment.

    DATA go_cut    TYPE REF TO zcl_zari002_processor.
    DATA go_notify TYPE REF TO ltd_notify.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS valid_request_is_saved     FOR TESTING.
    METHODS batch_and_currency_set     FOR TESTING.
    METHODS gl_account_is_padded       FOR TESTING.
    METHODS unknown_company_fails      FOR TESTING.
    METHODS nothing_saved_on_error     FOR TESTING.
    METHODS duplicate_is_rejected      FOR TESTING.
    METHODS broken_json_gives_012      FOR TESTING.
    METHODS unknown_bank_fails_207     FOR TESTING.
    METHODS bank_skipped_if_not_cheque FOR TESTING.
    METHODS callback_one_row_per_item  FOR TESTING.
    METHODS callback_carries_error     FOR TESTING.
    METHODS empty_payments_gives_013 FOR TESTING.
    METHODS header_error_carries_sf_id FOR TESTING.
    METHODS log_written_for_saved     FOR TESTING.
    METHODS log_written_for_rejected  FOR TESTING.
    METHODS log_msg_carries_item_id   FOR TESTING.

    METHODS sample_json
      IMPORTING iv_company_code   TYPE string DEFAULT `2000`
                iv_doc_no         TYPE string DEFAULT `1000000001`
                iv_payment_method TYPE string DEFAULT `Cheque`
                iv_bank_branch    TYPE string DEFAULT `0040129`
                iv_cheque_no      TYPE string DEFAULT `10020185`
      RETURNING VALUE(rv_result)  TYPE string.

    METHODS has_msgno
      IMPORTING it_error         TYPE zcl_zari002_processor=>tt_error
                iv_msgno         TYPE symsgno
      RETURNING VALUE(rv_result) TYPE abap_bool.

ENDCLASS.


CLASS ltc_processor IMPLEMENTATION.

  METHOD class_setup.
    go_osql = cl_osql_test_environment=>create(
                i_dependency_list = VALUE #( ( 'ZTAR_I002_PYMT' )
                                             ( 'ZTAR_I002_ITEM' )
                                             ( 'ZTAR_I002_HDRLOG' )
                                             ( 'ZTAR_I002_ITMLOG' )
                                             ( 'ZTAR_I002_MSGLOG' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    go_osql->destroy( ).
  ENDMETHOD.

  METHOD setup.
    go_osql->clear_doubles( ).
    go_notify = NEW ltd_notify( ).
    go_cut    = NEW zcl_zari002_processor( io_master_data = NEW ltd_master_data( )
                                           io_notify      = go_notify ).
  ENDMETHOD.


  METHOD sample_json.

    rv_result =
      `{`                                                       &&
      `  "RequestId": "REQ-TEST-0001",`                         &&
      `  "Payments": [`                                         &&
      `    {`                                                   &&
      `      "SalesforceId": "SF0000000000000001",`             &&
      `      "PaymentDocumentNo": "` && iv_doc_no && `",`        &&
      `      "NumberOfItemsInPayment": 2,`                       &&
      `      "CompanyCode": "` && iv_company_code && `",`        &&
      `      "PostingDate": "2026-08-15",`                       &&
      `      "GlAccount": "11011214",`                           &&
      `      "PaymentMethod": "` && iv_payment_method && `",`   &&
      `      "ChequeNo": "` && iv_cheque_no && `",`   &&
      `      "IssueDate": "2026-07-15",`                         &&
      `      "DueOn": "2026-08-31",`                             &&
      `      "ChequeBankBranch": "` && iv_bank_branch && `",`   &&
      `      "PaymentAmount": "9650.00",`                        &&
      `      "Items": [`                                         &&
      `        { "SalesforceItemId": "IT0000000000000001",`      &&
      `          "CustomerCode": "1000000002",`                  &&
      `          "AccountingDocument": "6000000001",`             &&
      `          "BillingDocument": "0090000000",`                &&
      `          "InvoicePostingDate": "2026-07-01",`              &&
      `          "InvoiceAmount": "1070.00",`                      &&
      `          "AmountPaid": "1070.00",`                         &&
      `          "SaleSubmitDate": "2026-08-15" },`                &&
      `        { "SalesforceItemId": "IT0000000000000002",`        &&
      `          "CustomerCode": "1000000002",`                    &&
      `          "AccountingDocument": "6000000003",`               &&
      `          "BillingDocument": "0090000002",`                  &&
      `          "InvoicePostingDate": "2026-08-03",`                &&
      `          "InvoiceAmount": "1605.00",`                        &&
      `          "AmountPaid": "500.00",`                             &&
      `          "PartialAmount": "X",`                                &&
      `          "SaleSubmitDate": "2026-08-15" }`                     &&
      `      ]`                                                        &&
      `    }`                                                          &&
      `  ]`                                                            &&
      `}`.

  ENDMETHOD.


  METHOD has_msgno.
    rv_result = xsdbool( line_exists( it_error[ msgno = iv_msgno ] ) ).
  ENDMETHOD.


  METHOD valid_request_is_saved.

    DATA(ls_out) = go_cut->process( sample_json( ) ).

    cl_abap_unit_assert=>assert_initial(
      act = ls_out-errors
      msg = 'ข้อมูลถูกต้องทั้งหมด ไม่ควรมี error' ).
    cl_abap_unit_assert=>assert_equals( exp = abap_true act = ls_out-success ).

    cl_abap_unit_assert=>assert_equals( exp = abap_true act = ls_out-success ).

    SELECT COUNT(*) FROM ztar_i002_pymt INTO @DATA(lv_header).
    SELECT COUNT(*) FROM ztar_i002_item INTO @DATA(lv_item).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lv_header ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lv_item ).

  ENDMETHOD.


  METHOD batch_and_currency_set.

    go_cut->process( sample_json( ) ).

    SELECT SINGLE FROM ztar_i002_pymt
      FIELDS request_id, currency, status, sap_payment_method
      INTO @DATA(ls_pymt).

    cl_abap_unit_assert=>assert_not_initial( act = ls_pymt-request_id ).
    cl_abap_unit_assert=>assert_equals( exp = 'THB' act = ls_pymt-currency ).
    cl_abap_unit_assert=>assert_equals( exp = 'N'   act = ls_pymt-status ).
    cl_abap_unit_assert=>assert_equals( exp = 'A'   act = ls_pymt-sap_payment_method ).

*   currency ต้องไหลลงถึง item ด้วย
    SELECT SINGLE FROM ztar_i002_item FIELDS currency INTO @DATA(lv_currency).
    cl_abap_unit_assert=>assert_equals( exp = 'THB' act = lv_currency ).

  ENDMETHOD.


  METHOD gl_account_is_padded.

    go_cut->process( sample_json( ) ).

    SELECT SINGLE FROM ztar_i002_pymt FIELDS gl_account INTO @DATA(lv_gl).

    cl_abap_unit_assert=>assert_equals(
      exp = '0011011214'
      act = lv_gl
      msg = 'ส่ง 11011214 เข้าไป ต้องเก็บเป็น 10 หลัก ไม่งั้น ZARE002 post ไม่ได้' ).

  ENDMETHOD.


  METHOD unknown_company_fails.

    DATA(ls_out) = go_cut->process( sample_json( iv_company_code = `9999` ) ).

    cl_abap_unit_assert=>assert_equals( exp = abap_false act = ls_out-success ).
    cl_abap_unit_assert=>assert_true( has_msgno( it_error = ls_out-errors iv_msgno = '200' ) ).

  ENDMETHOD.


  METHOD nothing_saved_on_error.

    go_cut->process( sample_json( iv_company_code = `9999` ) ).

    SELECT COUNT(*) FROM ztar_i002_pymt INTO @DATA(lv_header).
    SELECT COUNT(*) FROM ztar_i002_item INTO @DATA(lv_item).

    cl_abap_unit_assert=>assert_equals(
      exp = 0 act = lv_header msg = 'reject-all ต้องไม่บันทึก header' ).
    cl_abap_unit_assert=>assert_equals(
      exp = 0 act = lv_item   msg = 'reject-all ต้องไม่บันทึก item' ).

  ENDMETHOD.


  METHOD duplicate_is_rejected.

*   ยิงชุดแรกให้เข้า table ก่อน แล้วยิงชุดเดิมซ้ำ
    go_cut->process( sample_json( ) ).
    DATA(ls_out) = go_cut->process( sample_json( ) ).

    cl_abap_unit_assert=>assert_equals( exp = abap_false act = ls_out-success ).
    cl_abap_unit_assert=>assert_true( has_msgno( it_error = ls_out-errors iv_msgno = '010' ) ).

  ENDMETHOD.


  METHOD broken_json_gives_012.

    DATA(ls_out) = go_cut->process( `{ "SalesforceId": ` ).

    cl_abap_unit_assert=>assert_equals( exp = abap_false act = ls_out-success ).
    cl_abap_unit_assert=>assert_true( has_msgno( it_error = ls_out-errors iv_msgno = '012' ) ).
    cl_abap_unit_assert=>assert_not_initial(
      act = ls_out-status
      msg = 'parse พังก็ต้องมี Status ไม่ใช่ค่าว่าง' ).

  ENDMETHOD.


  METHOD unknown_bank_fails_207.

    DATA(ls_out) = go_cut->process( sample_json( iv_bank_branch = `9999999` ) ).

    cl_abap_unit_assert=>assert_equals( exp = abap_false act = ls_out-success ).
    cl_abap_unit_assert=>assert_true( has_msgno( it_error = ls_out-errors iv_msgno = '207' ) ).

  ENDMETHOD.


  METHOD bank_skipped_if_not_cheque.

    DATA(ls_out) = go_cut->process( sample_json( iv_payment_method = `Transfer`
                                                 iv_bank_branch    = `` ) ).

    cl_abap_unit_assert=>assert_false(
      act = has_msgno( it_error = ls_out-errors iv_msgno = '207' )
      msg = 'ไม่ได้จ่ายด้วยเช็ค ไม่ควรตรวจ bank' ).

  ENDMETHOD.


  METHOD callback_one_row_per_item.

    go_cut->process( sample_json( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( go_notify->gt_sent ) ).

    cl_abap_unit_assert=>assert_equals(
      exp = 'S' act = go_notify->gt_sent[ 1 ]-status ).
    cl_abap_unit_assert=>assert_equals(
      exp = 'IT0000000000000002' act = go_notify->gt_sent[ 2 ]-salesforce_item_id ).
    cl_abap_unit_assert=>assert_equals(
      exp = 'SF0000000000000001' act = go_notify->gt_sent[ 1 ]-salesforce_id ).

  ENDMETHOD.


  METHOD callback_carries_error.

    go_cut->process( sample_json( iv_company_code = `9999` ) ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( go_notify->gt_sent ) ).

    cl_abap_unit_assert=>assert_equals(
      exp = 'E' act = go_notify->gt_sent[ 1 ]-status ).

    cl_abap_unit_assert=>assert_not_initial(
      act = go_notify->gt_sent[ 1 ]-error_message
      msg = 'error ระดับ payment ต้องถูกส่งไปกับทุกบรรทัด ไม่งั้น SFDC เห็นแค่ E เฉย ๆ' ).

  ENDMETHOD.


  METHOD empty_payments_gives_013.

    DATA(ls_out) = go_cut->process( `{ "RequestId": "REQ-TEST-0001", "Payments": [] }` ).

    cl_abap_unit_assert=>assert_equals( exp = abap_false act = ls_out-success ).
    cl_abap_unit_assert=>assert_true( has_msgno( it_error = ls_out-errors iv_msgno = '013' ) ).

  ENDMETHOD.


  METHOD header_error_carries_sf_id.

*   107 เป็น error ระดับ header — SalesforceId มีอยู่ ต้องถูกส่งกลับไปด้วย
    DATA(ls_out) = go_cut->process( sample_json( iv_cheque_no = `` ) ).

    cl_abap_unit_assert=>assert_equals(
      exp = 'SF0000000000000001'
      act = ls_out-errors[ msgno = '107' ]-salesforce_id
      msg = 'error ระดับ header ต้องระบุ SalesforceId เมื่อมีข้อมูล' ).

  ENDMETHOD.


  METHOD log_written_for_saved.

    go_cut->process( sample_json( ) ).

    SELECT SINGLE FROM ztar_i002_hdrlog FIELDS status, request_body INTO @DATA(ls_hdr).
    SELECT COUNT(*) FROM ztar_i002_itmlog INTO @DATA(lv_item).
    SELECT COUNT(*) FROM ztar_i002_msglog INTO @DATA(lv_msg).

    cl_abap_unit_assert=>assert_equals( exp = 'S' act = ls_hdr-status ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_hdr-request_body
                                             msg = 'ต้องเก็บ JSON ของใบนี้' ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lv_item ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lv_msg
                                        msg = 'ใบผ่านต้องไม่มี message log' ).

  ENDMETHOD.


  METHOD log_written_for_rejected.

    DATA(ls_out) = go_cut->process( sample_json( iv_company_code = `9999` ) ).

    SELECT SINGLE FROM ztar_i002_hdrlog FIELDS status INTO @DATA(lv_status).
    SELECT FROM ztar_i002_msglog FIELDS msg_seq, message_area, message
      ORDER BY msg_seq INTO TABLE @DATA(lt_msg).

*   ใบตกต้องมี log เหมือนกัน — และเป็นใบที่ต้องดูมากที่สุด
    cl_abap_unit_assert=>assert_equals( exp = 'E' act = lv_status ).
    cl_abap_unit_assert=>assert_equals( exp = lines( ls_out-errors ) act = lines( lt_msg )
                                        msg = 'message log ต้องครบเท่า error' ).
    cl_abap_unit_assert=>assert_equals( exp = 'HEADER' act = lt_msg[ 1 ]-message_area ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lt_msg[ 1 ]-message CS 'ZARI002/200' )
                                      msg = 'message ต้องขึ้นต้นด้วย code' ).

  ENDMETHOD.


  METHOD log_msg_carries_item_id.

*   customer 9999999999 ไม่มีใน test double → 205 ระดับ item
    DATA(lv_json) = replace( val  = sample_json( )
                             sub  = `"CustomerCode": "1000000002"`
                             with = `"CustomerCode": "9999999999"`
                             occ  = 1 ).
    go_cut->process( lv_json ).

    SELECT SINGLE FROM ztar_i002_msglog FIELDS message_area, salesforce_item_id
      WHERE message_area = 'ITEM' INTO @DATA(ls_msg).

    cl_abap_unit_assert=>assert_equals( exp = 'IT0000000000000001' act = ls_msg-salesforce_item_id
                                        msg = 'error ระดับ item ต้องบอกว่า item ไหน' ).

  ENDMETHOD.

ENDCLASS.
