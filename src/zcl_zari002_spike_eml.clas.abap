CLASS zcl_zari002_spike_eml DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " ทดสอบ deep create ผ่าน EML ว่า managed runtime เขียนลง 2 table ถูกต้อง
    " throwaway — ลบทิ้งเมื่อจบ Phase 4
    INTERFACES if_oo_adt_classrun.
ENDCLASS.


CLASS zcl_zari002_spike_eml IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

*   salesforce_id ห้ามซ้ำ (unique index) จึง gen ใหม่ทุกครั้งที่รัน
    DATA(lv_sf_id) = |SFID{ cl_abap_context_info=>get_system_date( ) }| &&
                     |{ cl_abap_context_info=>get_system_time( ) }|.

    out->write( |Salesforce ID ที่ใช้ทดสอบ: { lv_sf_id }| ).

    MODIFY ENTITIES OF zr_zari002
      ENTITY Payment
        CREATE
          FIELDS ( SalesforceId PaymentDocumentNo NumberOfItems CompanyCode
                   PostingDate GLAccount PaymentMethod ChequeNo IssueDate DueOn
                   ChequeBankBranch RoundingDiff AdvancePayment Fees PaymentAmount )
          WITH VALUE #( ( %cid              = 'PAY1'
                          SalesforceId      = lv_sf_id
                          PaymentDocumentNo = '1000000001'
                          NumberOfItems     = 2
                          CompanyCode       = '2000'
                          PostingDate       = '20260815'
                          GLAccount         = '0011011214'
                          PaymentMethod     = 'Cheque'
                          ChequeNo          = '10020185'
                          IssueDate         = '20260715'
                          DueOn             = '20260831'
                          ChequeBankBranch  = '0040129'
                          RoundingDiff      = 0
                          AdvancePayment    = '60.00'
                          Fees              = '5.00'
                          PaymentAmount     = '9650.00' ) )

      ENTITY Payment
        CREATE BY \_Item
          FIELDS ( SalesforceItemId CustomerCode BillingNoteNo AccountingDocument
                   BillingDocument InvoicePostingDate InvoiceAmount AmountPaid
                   PartialAmount SaleSubmitDate )
          WITH VALUE #( ( %cid_ref = 'PAY1'
                          %target  = VALUE #(
                            ( %cid               = 'ITEM1'
                              SalesforceItemId   = |{ lv_sf_id }-1|
                              CustomerCode       = '1000000002'
                              BillingNoteNo      = 'BN00000001'
                              AccountingDocument = '6000000001'
                              BillingDocument    = '0090000000'
                              InvoicePostingDate = '20260701'
                              InvoiceAmount      = '1070.00'
                              AmountPaid         = '1070.00'
                              PartialAmount      = ''
                              SaleSubmitDate     = '20260815' )
                            ( %cid               = 'ITEM2'
                              SalesforceItemId   = |{ lv_sf_id }-2|
                              CustomerCode       = '1000000002'
                              BillingNoteNo      = 'BN00000002'
                              AccountingDocument = '6000000003'
                              BillingDocument    = '0090000002'
                              InvoicePostingDate = '20260803'
                              InvoiceAmount      = '1605.00'
                              AmountPaid         = '500.00'
                              PartialAmount      = 'X'
                              SaleSubmitDate     = '20260815' ) ) ) )

      MAPPED   DATA(ls_mapped)
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    IF ls_failed IS NOT INITIAL.
      out->write( '*** MODIFY ไม่ผ่าน ***' ).
      out->write( ls_failed ).
      out->write( ls_reported ).
      RETURN.
    ENDIF.

    out->write( |MODIFY ผ่าน — payment { lines( ls_mapped-payment ) } | &&
                |· item { lines( ls_mapped-item ) }| ).

    COMMIT ENTITIES RESPONSE OF zr_zari002
      FAILED   DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    IF ls_commit_failed IS NOT INITIAL.
      out->write( '*** COMMIT ไม่ผ่าน ***' ).
      out->write( ls_commit_failed ).
      out->write( ls_commit_reported ).
      RETURN.
    ENDIF.

    out->write( 'COMMIT ผ่าน' ).

*   อ่านกลับจาก table จริง เพื่อดูว่า managed runtime เขียนอะไรลงไปบ้าง
    SELECT SINGLE FROM ztar_i002_pymt
      FIELDS payment_uuid, salesforce_id, number_of_items, currency,
             sap_payment_method, status, error_message,
             created_by, created_at, last_changed_by, last_changed_at,
             local_last_changed_at
      WHERE salesforce_id = @lv_sf_id
      INTO @DATA(ls_pymt).

    out->write( '=== HEADER ที่ลง table ===' ).
    out->write( ls_pymt ).

    SELECT FROM ztar_i002_item
      FIELDS item_uuid, payment_uuid, salesforce_item_id, currency,
             partial_amount, status, created_by, created_at,
             last_changed_by, local_last_changed_at
      WHERE payment_uuid = @ls_pymt-payment_uuid
      ORDER BY salesforce_item_id
      INTO TABLE @DATA(lt_item).

    out->write( |=== ITEM ที่ลง table : { lines( lt_item ) } rows ===| ).
    out->write( lt_item ).

  ENDMETHOD.

ENDCLASS.
