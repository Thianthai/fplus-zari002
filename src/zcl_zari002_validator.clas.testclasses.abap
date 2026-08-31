CLASS ltc_validator DEFINITION FINAL
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    " ---- convert_payment_method ----
    METHODS cheque_maps_to_a          FOR TESTING.
    METHODS transfer_maps_to_t        FOR TESTING.
    METHODS mapping_ignores_case      FOR TESTING.
    METHODS mapping_ignores_spaces    FOR TESTING.
    METHODS unknown_word_maps_to_none FOR TESTING.

    " ---- to_internal_key ----
    METHODS key_gets_padded           FOR TESTING.
    METHODS padded_key_stays_same     FOR TESTING.
    METHODS blank_key_stays_blank     FOR TESTING.

    " ---- check_mandatory ----
    METHODS complete_header_is_ok     FOR TESTING.
    METHODS empty_header_reports_all  FOR TESTING.
    METHODS missing_gl_reports_104    FOR TESTING.

    " ---- check_number_of_items ----
    METHODS no_item_reports_001       FOR TESTING.
    METHODS matching_count_is_ok      FOR TESTING.
    METHODS wrong_count_reports_002   FOR TESTING.

    " ---- check_dates ----
    METHODS due_after_issue_is_ok     FOR TESTING.
    METHODS due_before_issue_rep_003  FOR TESTING.
    METHODS no_issue_date_is_ok       FOR TESTING.

    " ---- check_cheque_fields ----
    METHODS transfer_skips_cheque_chk FOR TESTING.
    METHODS cheque_complete_is_ok     FOR TESTING.
    METHODS cheque_empty_reports_4    FOR TESTING.

    " ---- check_amount_paid_total ----
    METHODS positive_total_is_ok      FOR TESTING.
    METHODS zero_total_reports_011    FOR TESTING.
    METHODS negative_total_rep_011    FOR TESTING.
    METHODS credit_note_still_ok      FOR TESTING.

    " ---- check_item_ids ----
    METHODS distinct_item_ids_are_ok  FOR TESTING.
    METHODS duplicate_id_reports_005  FOR TESTING.
    METHODS blank_id_reported_once    FOR TESTING.

    " ---- check_item_mandatory ----
    METHODS complete_item_is_ok       FOR TESTING.
    METHODS empty_item_reports_all    FOR TESTING.
    METHODS bad_partial_flag_rep_006  FOR TESTING.
    METHODS partial_flag_x_is_ok      FOR TESTING.

    " ---- helper ----
    METHODS valid_payment
      RETURNING VALUE(rs_result) TYPE zcl_zari002_validator=>ty_payment.

    METHODS valid_item
      RETURNING VALUE(rs_result) TYPE zcl_zari002_validator=>ty_item.

    METHODS assert_has
      IMPORTING it_finding TYPE zcl_zari002_validator=>tt_finding
                iv_msgno   TYPE symsgno.

    METHODS assert_clean
      IMPORTING it_finding TYPE zcl_zari002_validator=>tt_finding.

ENDCLASS.


CLASS ltc_validator IMPLEMENTATION.

* =====================================================================
* helper
* =====================================================================

  METHOD valid_payment.
    rs_result = VALUE #( salesforce_id        = 'SF0000000000000001'
                         payment_document_no  = '1000000001'
                         number_of_items_in_payment = 2
                         company_code         = '2000'
                         posting_date         = '20260815'
                         gl_account           = '0011011214'
                         payment_method       = 'Cheque'
                         sap_payment_method   = 'A'
                         cheque_no            = '10020185'
                         issue_date           = '20260715'
                         due_on               = '20260831'
                         cheque_bank_branch   = '0040129'
                         payment_amount       = '9650.00' ).
  ENDMETHOD.

  METHOD valid_item.
    rs_result = VALUE #( salesforce_item_id   = 'IT0000000000000001'
                         customer_code        = '1000000002'
                         accounting_document  = '6000000001'
                         billing_document     = '0090000000'
                         invoice_posting_date = '20260701'
                         invoice_amount       = '1070.00'
                         amount_paid          = '1070.00'
                         sale_submit_date     = '20260815' ).
  ENDMETHOD.

  METHOD assert_has.
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( it_finding[ msgno = iv_msgno ] ) )
      msg = |คาดว่าต้องเจอ message { iv_msgno }| ).
  ENDMETHOD.

  METHOD assert_clean.
    cl_abap_unit_assert=>assert_initial(
      act = it_finding
      msg = 'ไม่ควรมี finding' ).
  ENDMETHOD.

* =====================================================================
* convert_payment_method
* =====================================================================

  METHOD cheque_maps_to_a.
    cl_abap_unit_assert=>assert_equals(
      exp = 'A'
      act = zcl_zari002_validator=>convert_payment_method( 'Cheque' ) ).
  ENDMETHOD.

  METHOD transfer_maps_to_t.
    cl_abap_unit_assert=>assert_equals(
      exp = 'T'
      act = zcl_zari002_validator=>convert_payment_method( 'Transfer' ) ).
  ENDMETHOD.

  METHOD mapping_ignores_case.
    cl_abap_unit_assert=>assert_equals(
      exp = 'A'
      act = zcl_zari002_validator=>convert_payment_method( 'cheque' ) ).
  ENDMETHOD.

  METHOD mapping_ignores_spaces.
    cl_abap_unit_assert=>assert_equals(
      exp = 'A'
      act = zcl_zari002_validator=>convert_payment_method( ' Cheque' ) ).
  ENDMETHOD.

  METHOD unknown_word_maps_to_none.
    cl_abap_unit_assert=>assert_initial(
      act = zcl_zari002_validator=>convert_payment_method( 'Cash' )
      msg = 'คำที่ไม่รู้จักต้องคืนค่าว่าง ให้ validation ออก 202' ).
  ENDMETHOD.

* =====================================================================
* to_internal_key
* =====================================================================

  METHOD key_gets_padded.
    cl_abap_unit_assert=>assert_equals(
      exp = '0011011214'
      act = zcl_zari002_validator=>to_internal_key( '11011214' ) ).
  ENDMETHOD.

  METHOD padded_key_stays_same.
    cl_abap_unit_assert=>assert_equals(
      exp = '0011011214'
      act = zcl_zari002_validator=>to_internal_key( '0011011214' )
      msg = 'pad ซ้ำต้องได้ผลเท่าเดิม (API spec §4.1)' ).
  ENDMETHOD.

  METHOD blank_key_stays_blank.
    cl_abap_unit_assert=>assert_initial(
      act = zcl_zari002_validator=>to_internal_key( '' )
      msg = 'ค่าว่างห้ามกลายเป็น 0000000000 ไม่งั้น mandatory check จับไม่ได้' ).
  ENDMETHOD.

* =====================================================================
* check_mandatory
* =====================================================================

  METHOD complete_header_is_ok.
    assert_clean( zcl_zari002_validator=>check_mandatory( valid_payment( ) ) ).
  ENDMETHOD.

  METHOD empty_header_reports_all.
    DATA(lt_finding) = zcl_zari002_validator=>check_mandatory( VALUE #( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 7 act = lines( lt_finding ) ).
    assert_has( it_finding = lt_finding iv_msgno = '100' ).
    assert_has( it_finding = lt_finding iv_msgno = '106' ).
  ENDMETHOD.

  METHOD missing_gl_reports_104.
    DATA(ls_payment) = valid_payment( ).
    CLEAR ls_payment-gl_account.

    DATA(lt_finding) = zcl_zari002_validator=>check_mandatory( ls_payment ).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt_finding ) ).
    cl_abap_unit_assert=>assert_equals( exp = '104' act = lt_finding[ 1 ]-msgno ).
    cl_abap_unit_assert=>assert_equals( exp = 'gl_account' act = lt_finding[ 1 ]-field ).
  ENDMETHOD.

* =====================================================================
* check_number_of_items
* =====================================================================

  METHOD no_item_reports_001.
    DATA(lt_finding) = zcl_zari002_validator=>check_number_of_items(
                         iv_number_of_items = 0
                         iv_item_count      = 0 ).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt_finding ) ).
    assert_has( it_finding = lt_finding iv_msgno = '001' ).
  ENDMETHOD.

  METHOD matching_count_is_ok.
    assert_clean( zcl_zari002_validator=>check_number_of_items(
                    iv_number_of_items = 2
                    iv_item_count      = 2 ) ).
  ENDMETHOD.

  METHOD wrong_count_reports_002.
    DATA(lt_finding) = zcl_zari002_validator=>check_number_of_items(
                         iv_number_of_items = 3
                         iv_item_count      = 2 ).

    assert_has( it_finding = lt_finding iv_msgno = '002' ).
    cl_abap_unit_assert=>assert_equals( exp = '3' act = lt_finding[ 1 ]-msgv1 ).
    cl_abap_unit_assert=>assert_equals( exp = '2' act = lt_finding[ 1 ]-msgv2 ).
  ENDMETHOD.

* =====================================================================
* check_dates
* =====================================================================

  METHOD due_after_issue_is_ok.
    assert_clean( zcl_zari002_validator=>check_dates( valid_payment( ) ) ).
  ENDMETHOD.

  METHOD due_before_issue_rep_003.
    DATA(ls_payment) = valid_payment( ).
    ls_payment-due_on = '20260701'.

    assert_has( it_finding = zcl_zari002_validator=>check_dates( ls_payment )
                iv_msgno   = '003' ).
  ENDMETHOD.

  METHOD no_issue_date_is_ok.
    DATA(ls_payment) = valid_payment( ).
    CLEAR ls_payment-issue_date.

    assert_clean( zcl_zari002_validator=>check_dates( ls_payment ) ).
  ENDMETHOD.

* =====================================================================
* check_cheque_fields
* =====================================================================

  METHOD transfer_skips_cheque_chk.
    DATA(ls_payment) = valid_payment( ).
    ls_payment-sap_payment_method = 'T'.
    CLEAR: ls_payment-cheque_no, ls_payment-issue_date,
           ls_payment-due_on,    ls_payment-cheque_bank_branch.

    assert_clean( zcl_zari002_validator=>check_cheque_fields( ls_payment ) ).
  ENDMETHOD.

  METHOD cheque_complete_is_ok.
    assert_clean( zcl_zari002_validator=>check_cheque_fields( valid_payment( ) ) ).
  ENDMETHOD.

  METHOD cheque_empty_reports_4.
    DATA(ls_payment) = valid_payment( ).
    CLEAR: ls_payment-cheque_no, ls_payment-issue_date,
           ls_payment-due_on,    ls_payment-cheque_bank_branch.

    DATA(lt_finding) = zcl_zari002_validator=>check_cheque_fields( ls_payment ).

    cl_abap_unit_assert=>assert_equals( exp = 4 act = lines( lt_finding ) ).
    assert_has( it_finding = lt_finding iv_msgno = '107' ).
    assert_has( it_finding = lt_finding iv_msgno = '110' ).
  ENDMETHOD.

* =====================================================================
* check_amount_paid_total
* =====================================================================

  METHOD positive_total_is_ok.
    assert_clean( zcl_zari002_validator=>check_amount_paid_total(
                    iv_salesforce_id = 'SF01'
                    it_item          = VALUE #( ( amount_paid = '100.00' )
                                                ( amount_paid = '50.00' ) ) ) ).
  ENDMETHOD.

  METHOD zero_total_reports_011.
    assert_has(
      it_finding = zcl_zari002_validator=>check_amount_paid_total(
                     iv_salesforce_id = 'SF01'
                     it_item          = VALUE #( ( amount_paid = '100.00' )
                                                 ( amount_paid = '100.00-' ) ) )
      iv_msgno   = '011' ).
  ENDMETHOD.

  METHOD negative_total_rep_011.
    assert_has(
      it_finding = zcl_zari002_validator=>check_amount_paid_total(
                     iv_salesforce_id = 'SF01'
                     it_item          = VALUE #( ( amount_paid = '50.00-' ) ) )
      iv_msgno   = '011' ).
  ENDMETHOD.

  METHOD credit_note_still_ok.
    " CN ติดลบได้ ตราบใดที่ผลรวมยังเป็นบวก
    assert_clean( zcl_zari002_validator=>check_amount_paid_total(
                    iv_salesforce_id = 'SF01'
                    it_item          = VALUE #( ( amount_paid = '1000.00' )
                                                ( amount_paid = '200.00-' ) ) ) ).
  ENDMETHOD.

* =====================================================================
* check_item_ids
* =====================================================================

  METHOD distinct_item_ids_are_ok.
    assert_clean( zcl_zari002_validator=>check_item_ids(
                    VALUE #( ( salesforce_item_id = 'IT01' )
                             ( salesforce_item_id = 'IT02' ) ) ) ).
  ENDMETHOD.

  METHOD duplicate_id_reports_005.
    DATA(lt_finding) = zcl_zari002_validator=>check_item_ids(
                         VALUE #( ( salesforce_item_id = 'IT01' )
                                  ( salesforce_item_id = 'IT01' ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt_finding ) ).
    assert_has( it_finding = lt_finding iv_msgno = '005' ).
  ENDMETHOD.

  METHOD blank_id_reported_once.
    DATA(lt_finding) = zcl_zari002_validator=>check_item_ids(
                         VALUE #( ( salesforce_item_id = space )
                                  ( salesforce_item_id = space ) ) ).

    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = lines( lt_finding )
      msg = 'ไม่มี id ให้อ้าง ออกซ้ำหลายรอบก็ไม่ได้ข้อมูลเพิ่ม' ).
    assert_has( it_finding = lt_finding iv_msgno = '111' ).
  ENDMETHOD.

* =====================================================================
* check_item_mandatory
* =====================================================================

  METHOD complete_item_is_ok.
    assert_clean( zcl_zari002_validator=>check_item_mandatory( valid_item( ) ) ).
  ENDMETHOD.

  METHOD empty_item_reports_all.
    DATA(lt_finding) = zcl_zari002_validator=>check_item_mandatory( VALUE #( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 7 act = lines( lt_finding ) ).
    assert_has( it_finding = lt_finding iv_msgno = '112' ).
    assert_has( it_finding = lt_finding iv_msgno = '118' ).
  ENDMETHOD.

  METHOD bad_partial_flag_rep_006.
    DATA(ls_item) = valid_item( ).
    ls_item-partial_amount = 'Y'.

    assert_has( it_finding = zcl_zari002_validator=>check_item_mandatory( ls_item )
                iv_msgno   = '006' ).
  ENDMETHOD.

  METHOD partial_flag_x_is_ok.
    DATA(ls_item) = valid_item( ).
    ls_item-partial_amount = 'X'.

    assert_clean( zcl_zari002_validator=>check_item_mandatory( ls_item ) ).
  ENDMETHOD.

ENDCLASS.
