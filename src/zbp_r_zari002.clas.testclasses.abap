CLASS ltd_master_data DEFINITION FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_zari002_master_data.
ENDCLASS.


CLASS ltd_master_data IMPLEMENTATION.

  METHOD zif_zari002_master_data~get_company_codes.
    " รู้จักแค่ 2000 = THB / TH
    LOOP AT it_company_code ASSIGNING FIELD-SYMBOL(<lfs_cc>).
      IF <lfs_cc> = '2000'.
        INSERT VALUE #( company_code = '2000'
                        currency     = 'THB'
                        country      = 'TH' ) INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_zari002_master_data~find_unknown_gl_accounts.
    " รู้จักแค่ 2000 / 0011011214
    LOOP AT it_gl_key ASSIGNING FIELD-SYMBOL(<lfs_k>).
      IF <lfs_k>-company_code <> '2000' OR <lfs_k>-gl_account <> '0011011214'.
        INSERT <lfs_k> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_zari002_master_data~find_unknown_pymt_methods.
    " รู้จักแค่ TH / A และ TH / T
    LOOP AT it_payment_method_key ASSIGNING FIELD-SYMBOL(<lfs_k>).
      IF NOT ( <lfs_k>-country = 'TH'
               AND ( <lfs_k>-payment_method = 'A' OR <lfs_k>-payment_method = 'T' ) ).
        INSERT <lfs_k> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_zari002_master_data~find_unknown_customers.
    " รู้จักแค่ 1000000002
    LOOP AT it_customer ASSIGNING FIELD-SYMBOL(<lfs_c>).
      IF <lfs_c> <> '1000000002'.
        INSERT <lfs_c> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS ltc_bo DEFINITION FINAL
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-DATA go_osql TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS valid_payment_is_created  FOR TESTING.
    METHODS unknown_company_code_fails FOR TESTING.
    METHODS duplicate_is_rejected      FOR TESTING.

ENDCLASS.


CLASS ltc_bo IMPLEMENTATION.

  METHOD class_setup.
    go_osql = cl_osql_test_environment=>create(
                i_dependency_list = VALUE #( ( 'ZTAR_I002_PYMT' )
                                             ( 'ZTAR_I002_ITEM' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    go_osql->destroy( ).
  ENDMETHOD.

  METHOD setup.
    go_osql->clear_doubles( ).
    lhc_Payment=>set_master_data( NEW ltd_master_data( ) ).
  ENDMETHOD.


  METHOD valid_payment_is_created.

*   --- probe: double ถูก inject จริงไหม ---
    DATA lt_cc_probe TYPE zif_zari002_master_data=>tt_company_code.
    INSERT CONV #( '2000' ) INTO TABLE lt_cc_probe.

    DATA(lt_cc_known) = lhc_Payment=>master_data( )->get_company_codes( lt_cc_probe ).

    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = lines( lt_cc_known )
      msg = 'A: double ต้องรู้จัก company code 2000' ).

    DATA lt_gl_probe TYPE zif_zari002_master_data=>tt_gl_key.
    INSERT VALUE #( company_code = '2000' gl_account = '0011011214' ) INTO TABLE lt_gl_probe.
    INSERT VALUE #( company_code = '2000' gl_account = '11011214'   ) INTO TABLE lt_gl_probe.

    DATA(lt_gl_unknown) = lhc_Payment=>master_data( )->find_unknown_gl_accounts( lt_gl_probe ).

    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = lines( lt_gl_unknown )
      msg = 'B: double ต้องรู้จักเฉพาะตัวที่ pad แล้ว (คืน unknown 1 ตัว)' ).

    MODIFY ENTITIES OF zr_zari002
      ENTITY Payment
        CREATE FIELDS ( SalesforceId PaymentDocumentNo NumberOfItemsInPayment
                        CompanyCode PostingDate GLAccount PaymentMethod
                        ChequeNo IssueDate DueOn ChequeBankBranch PaymentAmount )
          WITH VALUE #( ( %cid                   = 'P1'
                          SalesforceId           = 'SF0000000000000001'
                          PaymentDocumentNo      = '1000000001'
                          NumberOfItemsInPayment = 1
                          CompanyCode            = '2000'
                          PostingDate            = '20260815'
                          GLAccount              = '11011214'
                          PaymentMethod          = 'Cheque'
                          ChequeNo               = '10020185'
                          IssueDate              = '20260715'
                          DueOn                  = '20260831'
                          ChequeBankBranch       = '0040129'
                          PaymentAmount          = '1070.00' ) )
      ENTITY Payment
        CREATE BY \_Item
          FIELDS ( SalesforceItemId CustomerCode AccountingDocument BillingDocument
                   InvoicePostingDate InvoiceAmount AmountPaid SaleSubmitDate )
          WITH VALUE #( ( %cid_ref = 'P1'
                          %target  = VALUE #( ( %cid               = 'I1'
                                                SalesforceItemId   = 'IT0000000000000001'
                                                CustomerCode       = '1000000002'
                                                AccountingDocument = '6000000001'
                                                BillingDocument    = '0090000000'
                                                InvoicePostingDate = '20260701'
                                                InvoiceAmount      = '1070.00'
                                                AmountPaid         = '1070.00'
                                                SaleSubmitDate     = '20260815' ) ) ) )
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    cl_abap_unit_assert=>assert_initial(
      act = ls_failed
      msg = 'ข้อมูลถูกต้องทั้งหมด ไม่ควรมี failed' ).

    COMMIT ENTITIES RESPONSE OF zr_zari002
      FAILED   DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

*   รวบเลข message มาใส่ข้อความ assert เพื่อให้รู้ทันทีว่าตัวไหน fail
    DATA lv_msgs TYPE string.

    LOOP AT ls_commit_reported-payment ASSIGNING FIELD-SYMBOL(<lfs_rep>).
      IF <lfs_rep>-%msg IS BOUND.
        lv_msgs = |{ lv_msgs } P{ <lfs_rep>-%msg->if_t100_message~t100key-msgno }|.
      ENDIF.
    ENDLOOP.

    LOOP AT ls_commit_reported-item ASSIGNING FIELD-SYMBOL(<lfs_irep>).
      IF <lfs_irep>-%msg IS BOUND.
        lv_msgs = |{ lv_msgs } I{ <lfs_irep>-%msg->if_t100_message~t100key-msgno }|.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_initial(
      act = ls_commit_failed
      msg = |validation ที่ fail: { lv_msgs }| ).

    cl_abap_unit_assert=>assert_initial(
      act = ls_commit_failed
      msg = 'validation ทั้ง 12 ตัวควรผ่านหมด' ).

    SELECT SINGLE FROM ztar_i002_pymt
      FIELDS batch_id, gl_account, sap_payment_method, currency, status
      WHERE salesforce_id = 'SF0000000000000001'
      INTO @DATA(ls_pymt).

    cl_abap_unit_assert=>assert_equals( exp = 'THB'        act = ls_pymt-currency ).
    cl_abap_unit_assert=>assert_equals( exp = 'N'          act = ls_pymt-status ).
    cl_abap_unit_assert=>assert_equals( exp = 'A'          act = ls_pymt-sap_payment_method ).
    cl_abap_unit_assert=>assert_equals( exp = '0011011214' act = ls_pymt-gl_account ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_pymt-batch_id ).

  ENDMETHOD.


  METHOD unknown_company_code_fails.

    MODIFY ENTITIES OF zr_zari002
      ENTITY Payment
        CREATE FIELDS ( SalesforceId PaymentDocumentNo NumberOfItemsInPayment
                        CompanyCode PostingDate GLAccount PaymentMethod PaymentAmount )
          WITH VALUE #( ( %cid                   = 'P1'
                          SalesforceId           = 'SF0000000000000002'
                          PaymentDocumentNo      = '1000000002'
                          NumberOfItemsInPayment = 1
                          CompanyCode            = '9999'
                          PostingDate            = '20260815'
                          GLAccount              = '11011214'
                          PaymentMethod          = 'Transfer'
                          PaymentAmount          = '1070.00' ) )
      ENTITY Payment
        CREATE BY \_Item
          FIELDS ( SalesforceItemId CustomerCode AccountingDocument BillingDocument
                   InvoicePostingDate InvoiceAmount AmountPaid SaleSubmitDate )
          WITH VALUE #( ( %cid_ref = 'P1'
                          %target  = VALUE #( ( %cid               = 'I1'
                                                SalesforceItemId   = 'IT0000000000000002'
                                                CustomerCode       = '1000000002'
                                                AccountingDocument = '6000000002'
                                                BillingDocument    = '0090000001'
                                                InvoicePostingDate = '20260701'
                                                InvoiceAmount      = '1070.00'
                                                AmountPaid         = '1070.00'
                                                SaleSubmitDate     = '20260815' ) ) ) ).

    COMMIT ENTITIES RESPONSE OF zr_zari002
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = ls_failed-payment
      msg = 'company code 9999 ไม่มีจริง ต้อง reject' ).

    DATA(lv_found) = abap_false.
    LOOP AT ls_reported-payment ASSIGNING FIELD-SYMBOL(<lfs_rep>).
      IF <lfs_rep>-%msg IS BOUND
     AND <lfs_rep>-%msg->if_t100_message~t100key-msgno = '200'.
        lv_found = abap_true.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = 'ต้องได้ message 200 Company code does not exist' ).

  ENDMETHOD.


  METHOD duplicate_is_rejected.

    TYPES: tt_pymt TYPE STANDARD TABLE OF ztar_i002_pymt WITH EMPTY KEY,
           tt_item TYPE STANDARD TABLE OF ztar_i002_item WITH EMPTY KEY.

*   ใส่ข้อมูลที่ "เคยมีอยู่แล้ว" ลง double
    go_osql->insert_test_data( VALUE tt_pymt(
      ( payment_uuid        = '11111111111111111111111111111111'
        payment_document_no = '1000000003'
        status              = 'N' ) ) ).

    go_osql->insert_test_data( VALUE tt_item(
      ( item_uuid        = '22222222222222222222222222222222'
        payment_uuid     = '11111111111111111111111111111111'
        billing_document = '0090000009' ) ) ).

    MODIFY ENTITIES OF zr_zari002
      ENTITY Payment
        CREATE FIELDS ( SalesforceId PaymentDocumentNo NumberOfItemsInPayment
                        CompanyCode PostingDate GLAccount PaymentMethod PaymentAmount )
          WITH VALUE #( ( %cid                   = 'P1'
                          SalesforceId           = 'SF0000000000000003'
                          PaymentDocumentNo      = '1000000003'
                          NumberOfItemsInPayment = 1
                          CompanyCode            = '2000'
                          PostingDate            = '20260815'
                          GLAccount              = '11011214'
                          PaymentMethod          = 'Transfer'
                          PaymentAmount          = '1070.00' ) )
      ENTITY Payment
        CREATE BY \_Item
          FIELDS ( SalesforceItemId CustomerCode AccountingDocument BillingDocument
                   InvoicePostingDate InvoiceAmount AmountPaid SaleSubmitDate )
          WITH VALUE #( ( %cid_ref = 'P1'
                          %target  = VALUE #( ( %cid               = 'I1'
                                                SalesforceItemId   = 'IT0000000000000003'
                                                CustomerCode       = '1000000002'
                                                AccountingDocument = '6000000003'
                                                BillingDocument    = '0090000009'
                                                InvoicePostingDate = '20260701'
                                                InvoiceAmount      = '1070.00'
                                                AmountPaid         = '1070.00'
                                                SaleSubmitDate     = '20260815' ) ) ) ).

    COMMIT ENTITIES RESPONSE OF zr_zari002
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    DATA(lv_found) = abap_false.
    LOOP AT ls_reported-payment ASSIGNING FIELD-SYMBOL(<lfs_rep>).
      IF <lfs_rep>-%msg IS BOUND
     AND <lfs_rep>-%msg->if_t100_message~t100key-msgno = '010'.
        lv_found = abap_true.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = 'payment_document_no + billing_document ซ้ำ ต้องได้ message 010' ).

  ENDMETHOD.

ENDCLASS.
