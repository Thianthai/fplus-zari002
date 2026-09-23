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

  METHOD zif_zari002_master_data~find_cleared_documents.
*   billing document ใน fixture ยังเปิดอยู่ · นอกนั้นถือว่า clear แล้ว
    LOOP AT it_billing_document ASSIGNING FIELD-SYMBOL(<lfs_d>).
      IF <lfs_d> <> '0090000000' AND <lfs_d> <> '0090000002'.
        INSERT <lfs_d> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS ltd_result DEFINITION FOR TESTING INHERITING FROM zcl_zari002_sfdc_result.
  PUBLIC SECTION.
    "! เก็บ record ที่จะยิงไว้ตรวจ แทนที่จะยิงจริง
    DATA gs_sent TYPE zcl_zari002_sfdc_result=>ty_record.
    " ตอบเหมือน SFDC รับ record แล้ว
    METHODS send REDEFINITION.
ENDCLASS.

CLASS ltd_result IMPLEMENTATION.
  METHOD send.
    gs_sent               = is_record.
    rs_result-http_status = zcl_zari002_sfdc_result=>gc_http_created.
    rs_result-success     = abap_true.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_processor DEFINITION FINAL
  FOR TESTING
  DURATION SHORT
  RISK LEVEL DANGEROUS.

  PRIVATE SECTION.

    CLASS-DATA go_osql TYPE REF TO if_osql_test_environment.

    DATA go_cut    TYPE REF TO zcl_zari002_processor.
    DATA go_result TYPE REF TO ltd_result.

    "! salesforce_id ของ fixture — ใช้เป็น WHERE ในทุก SELECT ของ test (ATC บังคับ)
    CONSTANTS gc_sf_id TYPE ztar_i002_pymt-salesforce_id VALUE 'SF0000000000000001'.

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
    METHODS callback_success_record   FOR TESTING.
    METHODS callback_failed_record    FOR TESTING.
    METHODS callback_result_in_hdrlog FOR TESTING.
    METHODS empty_payments_gives_013 FOR TESTING.
    METHODS header_error_carries_sf_id FOR TESTING.
    METHODS log_written_for_saved     FOR TESTING.
    METHODS log_written_for_rejected  FOR TESTING.
    METHODS log_msg_carries_item_id   FOR TESTING.
    METHODS cleared_document_fails_206 FOR TESTING.
    METHODS rejected_row_can_be_resent FOR TESTING.

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

    "! payment_uuid ของใบ fixture — อ่านจาก HDRLOG เพราะเขียนทุกใบทั้งผ่านและตก
    METHODS payment_uuid
      RETURNING VALUE(rv_result) TYPE sysuuid_x16.

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
    go_result = NEW ltd_result( ).
    go_cut    = NEW zcl_zari002_processor( io_master_data = NEW ltd_master_data( )
                                           io_result      = go_result ).
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

    DATA(lv_uuid) = payment_uuid( ).

    SELECT COUNT(*) FROM ztar_i002_pymt WHERE salesforce_id = @gc_sf_id INTO @DATA(lv_header).
    SELECT COUNT(*) FROM ztar_i002_item WHERE payment_uuid  = @lv_uuid  INTO @DATA(lv_item).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lv_header ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lv_item ).

  ENDMETHOD.


  METHOD batch_and_currency_set.

    go_cut->process( sample_json( ) ).

    SELECT SINGLE FROM ztar_i002_pymt
      FIELDS request_id, currency, status
      WHERE salesforce_id = @gc_sf_id
      INTO @DATA(ls_pymt).

    cl_abap_unit_assert=>assert_not_initial( act = ls_pymt-request_id ).
    cl_abap_unit_assert=>assert_equals( exp = 'THB' act = ls_pymt-currency ).
    cl_abap_unit_assert=>assert_equals( exp = 'N'   act = ls_pymt-status ).

    " currency ต้องไหลลงถึง item ด้วย
    SELECT SINGLE FROM ztar_i002_item
      FIELDS currency
      WHERE payment_uuid = @( payment_uuid( ) )
      INTO @DATA(lv_currency).

    cl_abap_unit_assert=>assert_equals( exp = 'THB' act = lv_currency ).

  ENDMETHOD.


  METHOD gl_account_is_padded.

    go_cut->process( sample_json( ) ).

    SELECT SINGLE FROM ztar_i002_pymt
      FIELDS gl_account
      WHERE salesforce_id = @gc_sf_id
      INTO @DATA(lv_gl).

    cl_abap_unit_assert=>assert_equals(
      exp = '0011011214'
      act = lv_gl
      msg = 'ส่ง 8 หลักเข้าไป ต้องเก็บเป็น 10 หลัก ไม่งั้น ZARE002 post ไม่ได้' ).

  ENDMETHOD.


  METHOD unknown_company_fails.

    DATA(ls_out) = go_cut->process( sample_json( iv_company_code = `9999` ) ).

    cl_abap_unit_assert=>assert_equals( exp = abap_false act = ls_out-success ).
    cl_abap_unit_assert=>assert_true( has_msgno( it_error = ls_out-errors iv_msgno = '200' ) ).

  ENDMETHOD.


  METHOD nothing_saved_on_error.

    go_cut->process( sample_json( iv_company_code = `9999` ) ).

    DATA(lv_uuid) = payment_uuid( ).

    SELECT COUNT(*) FROM ztar_i002_pymt WHERE salesforce_id = @gc_sf_id INTO @DATA(lv_header).
    SELECT COUNT(*) FROM ztar_i002_item WHERE payment_uuid  = @lv_uuid  INTO @DATA(lv_item).

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


  METHOD callback_success_record.

    go_cut->process( sample_json( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 'Payment Response'    act = go_result->gs_sent-interface ).
    cl_abap_unit_assert=>assert_equals( exp = 'SF0000000000000001' act = go_result->gs_sent-reference_id ).
    cl_abap_unit_assert=>assert_equals( exp = 'S'                  act = go_result->gs_sent-status ).
    cl_abap_unit_assert=>assert_equals( exp = 'All payments saved successfully'
                                        act = go_result->gs_sent-message ).
    cl_abap_unit_assert=>assert_initial( act = go_result->gs_sent-request_body
                                         msg = 'ZARI002 ไม่ส่ง Request_Body__c (D1-A)' ).

  ENDMETHOD.


  METHOD callback_failed_record.

*   เช็คไม่มี cheque no / issue date / due on / bank → 4 error ระดับ header
    DATA(lv_json) = replace( val = sample_json( iv_cheque_no = `` iv_bank_branch = `` )
                             sub = `"IssueDate": "2026-07-15",` with = `` occ = 1 ).
    lv_json = replace( val = lv_json sub = `"DueOn": "2026-08-31",` with = `` occ = 1 ).

    go_cut->process( lv_json ).

    cl_abap_unit_assert=>assert_equals( exp = 'E' act = go_result->gs_sent-status ).
    cl_abap_unit_assert=>assert_equals(
      exp = `Cheque number is required for payment method Cheque, `
         && `Issue date is required for payment method Cheque, `
         && `Due date is required for payment method Cheque, `
         && `Bank/branch is required for payment method Cheque`
      act = go_result->gs_sent-message
      msg = 'msgtx ต่อกันด้วย ", " ไม่มี code นำหน้า (D3)' ).

  ENDMETHOD.


  METHOD callback_result_in_hdrlog.

    go_cut->process( sample_json( ) ).

    SELECT SINGLE FROM ztar_i002_hdrlog
      FIELDS salesforce_status, salesforce_message
      WHERE salesforce_id = @gc_sf_id
      INTO @DATA(ls_log).

    cl_abap_unit_assert=>assert_equals( exp = 'S'   act = ls_log-salesforce_status
                                        msg = 'double ตอบ 201 ต้องได้ S' ).
    cl_abap_unit_assert=>assert_equals( exp = '201' act = ls_log-salesforce_message
                                        msg = 'เก็บ HTTP code' ).

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

    DATA(lv_uuid) = payment_uuid( ).

    SELECT SINGLE FROM ztar_i002_hdrlog FIELDS status, request_body
      WHERE payment_uuid = @lv_uuid INTO @DATA(ls_hdr).
    SELECT COUNT(*) FROM ztar_i002_itmlog WHERE payment_uuid = @lv_uuid INTO @DATA(lv_item).
    SELECT COUNT(*) FROM ztar_i002_msglog WHERE payment_uuid = @lv_uuid INTO @DATA(lv_msg).

    cl_abap_unit_assert=>assert_equals( exp = 'S' act = ls_hdr-status ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_hdr-request_body
                                             msg = 'ต้องเก็บ JSON ของใบนี้' ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lv_item ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lv_msg
                                        msg = 'ใบผ่านต้องไม่มี message log' ).

  ENDMETHOD.


  METHOD log_written_for_rejected.

    DATA(ls_out) = go_cut->process( sample_json( iv_company_code = `9999` ) ).

    DATA(lv_uuid) = payment_uuid( ).

    SELECT SINGLE FROM ztar_i002_hdrlog FIELDS status
      WHERE payment_uuid = @lv_uuid INTO @DATA(lv_status).
    SELECT FROM ztar_i002_msglog FIELDS msg_seq, message_area, message
      WHERE payment_uuid = @lv_uuid
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


  METHOD cleared_document_fails_206.

*   0090000009 ไม่อยู่ในรายการเปิดของ test double → ถือว่า clear แล้ว
    DATA(lv_json) = replace( val  = sample_json( )
                             sub  = `"BillingDocument": "0090000002"`
                             with = `"BillingDocument": "0090000009"`
                             occ  = 1 ).
    DATA(ls_out) = go_cut->process( lv_json ).

    cl_abap_unit_assert=>assert_equals( exp = abap_false act = ls_out-success ).
    cl_abap_unit_assert=>assert_true( act = has_msgno( it_error = ls_out-errors iv_msgno = '206' ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 'IT0000000000000002'
      act = ls_out-errors[ msgno = '206' ]-salesforce_item_id
      msg = '206 ต้องระบุว่า item ไหน' ).

  ENDMETHOD.


  METHOD rejected_row_can_be_resent.

*   เคส 1 ของ functional: รอบแรกลง table เป็น N → ZARE002 post ไม่ผ่านเป็น E → SF ส่งใหม่ต้องรับ
    go_cut->process( sample_json( ) ).
    UPDATE ztar_i002_pymt SET status = 'E' WHERE status = 'N' AND salesforce_id = @gc_sf_id.

    DATA(ls_out) = go_cut->process( sample_json( ) ).

    cl_abap_unit_assert=>assert_equals( exp = abap_true act = ls_out-success
                                        msg = 'ใบที่ post ไม่ผ่าน ต้องส่งแก้เข้ามาใหม่ได้' ).
    cl_abap_unit_assert=>assert_false( act = has_msgno( it_error = ls_out-errors iv_msgno = '010' ) ).

    SELECT COUNT(*) FROM ztar_i002_pymt WHERE salesforce_id = @gc_sf_id INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lv_count
                                        msg = 'ต้องมี 2 row: E เดิม + N ใหม่' ).

  ENDMETHOD.


  METHOD payment_uuid.
    SELECT SINGLE payment_uuid FROM ztar_i002_hdrlog
      WHERE salesforce_id = @gc_sf_id
      INTO @rv_result.
  ENDMETHOD.

ENDCLASS.
