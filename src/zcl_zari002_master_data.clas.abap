CLASS zcl_zari002_master_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_zari002_master_data.
ENDCLASS.



CLASS ZCL_ZARI002_MASTER_DATA IMPLEMENTATION.


  METHOD zif_zari002_master_data~get_company_codes.

    DATA lr_company_code TYPE RANGE OF zif_zari002_master_data=>ty_company_code.

    IF it_company_code IS INITIAL.
      RETURN.
    ENDIF.

    lr_company_code = VALUE #( FOR <lfs_cc> IN it_company_code
                             ( sign = 'I' option = 'EQ' low = <lfs_cc> ) ).

    SELECT FROM I_CompanyCode
      FIELDS CompanyCode AS company_code,
             Currency    AS currency,
             Country     AS country
      WHERE CompanyCode IN @lr_company_code
      INTO TABLE @rt_result.

  ENDMETHOD.


  METHOD zif_zari002_master_data~find_unknown_gl_accounts.

    DATA lr_company_code TYPE RANGE OF zif_zari002_master_data=>ty_company_code.
    DATA lr_gl_account   TYPE RANGE OF zif_zari002_master_data=>ty_gl_account.

    IF it_gl_key IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT it_gl_key ASSIGNING FIELD-SYMBOL(<lfs_key>).

      IF NOT line_exists( lr_company_code[ low = <lfs_key>-company_code ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_key>-company_code ) TO lr_company_code.
      ENDIF.

      IF NOT line_exists( lr_gl_account[ low = <lfs_key>-gl_account ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_key>-gl_account ) TO lr_gl_account.
      ENDIF.

    ENDLOOP.

    SELECT FROM I_GLAccountInCompanyCode WITH PRIVILEGED ACCESS
      FIELDS CompanyCode AS company_code,
             GLAccount   AS gl_account
      WHERE CompanyCode IN @lr_company_code
        AND GLAccount   IN @lr_gl_account
      INTO TABLE @DATA(lt_existing).

    LOOP AT it_gl_key ASSIGNING <lfs_key>.
      IF NOT line_exists( lt_existing[ company_code = <lfs_key>-company_code
                                       gl_account   = <lfs_key>-gl_account ] ).
        INSERT <lfs_key> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_zari002_master_data~find_unknown_customers.

    DATA lr_customer TYPE RANGE OF zif_zari002_master_data=>ty_customer.

    IF it_customer IS INITIAL.
      RETURN.
    ENDIF.

    lr_customer = VALUE #( FOR <lfs_cust> IN it_customer
                         ( sign = 'I' option = 'EQ' low = <lfs_cust> ) ).

    SELECT FROM I_Customer WITH PRIVILEGED ACCESS
      FIELDS Customer AS customer
      WHERE Customer IN @lr_customer
      INTO TABLE @DATA(lt_existing).

    LOOP AT it_customer ASSIGNING FIELD-SYMBOL(<lfs_c>).
      IF NOT line_exists( lt_existing[ customer = <lfs_c> ] ).
        INSERT <lfs_c> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_zari002_master_data~find_unknown_banks.

    DATA lr_country TYPE RANGE OF zif_zari002_master_data=>ty_country.
    DATA lr_bank    TYPE RANGE OF zif_zari002_master_data=>ty_bank.

    IF it_bank_key IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT it_bank_key ASSIGNING FIELD-SYMBOL(<lfs_bank>).

      IF NOT line_exists( lr_country[ low = <lfs_bank>-country ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_bank>-country ) TO lr_country.
      ENDIF.

      IF NOT line_exists( lr_bank[ low = <lfs_bank>-bank ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_bank>-bank ) TO lr_bank.
      ENDIF.

    ENDLOOP.

    SELECT FROM I_Bank_2 WITH PRIVILEGED ACCESS
      FIELDS BankCountry    AS country,
             BankInternalID AS bank
      WHERE BankCountry    IN @lr_country
        AND BankInternalID IN @lr_bank
      INTO TABLE @DATA(lt_existing).

    LOOP AT it_bank_key ASSIGNING <lfs_bank>.
      IF NOT line_exists( lt_existing[ country = <lfs_bank>-country
                                       bank    = <lfs_bank>-bank ] ).
        INSERT <lfs_bank> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_zari002_master_data~find_cleared_documents.

    DATA lr_billing TYPE RANGE OF zif_zari002_master_data=>ty_billing_document.

    IF it_billing_document IS INITIAL.
      RETURN.
    ENDIF.

    lr_billing = VALUE #( FOR <lfs_doc> IN it_billing_document
                        ( sign = 'I' option = 'EQ' low = <lfs_doc> ) ).

    SELECT FROM I_OperationalAcctgDocItem WITH PRIVILEGED ACCESS
      FIELDS OriginalReferenceDocument AS billing_document
      WHERE FinancialAccountType      = 'D'
        AND OriginalReferenceDocument IN @lr_billing
        AND ClearingJournalEntry      = @space
      INTO TABLE @DATA(lt_open).

    LOOP AT it_billing_document ASSIGNING FIELD-SYMBOL(<lfs_billing>).
      IF NOT line_exists( lt_open[ billing_document = <lfs_billing> ] ).
        INSERT <lfs_billing> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_zari002_master_data~get_cash_sale_invoices.

    DATA lr_sales_order TYPE RANGE OF zif_zari002_master_data=>ty_sales_order.

    IF it_sales_order IS INITIAL.
      RETURN.
    ENDIF.

    lr_sales_order = VALUE #( FOR <lfs_so> IN it_sales_order
                            ( sign = 'I' option = 'EQ' low = <lfs_so> ) ).

    " SO -> billing document -> FI document
    " เอาเฉพาะ invoice (M) เพราะ view รวมเอกสารยกเลิกและ credit memo ไว้ด้วย
    " บิล 1 ใบมีหลายบรรทัด จึงต้อง DISTINCT
    SELECT FROM I_BillingDocumentItem WITH PRIVILEGED ACCESS AS item
      INNER JOIN I_BillingDocument WITH PRIVILEGED ACCESS AS header
        ON header~BillingDocument = item~BillingDocument
      INNER JOIN I_OperationalAcctgDocItem WITH PRIVILEGED ACCESS AS fi
        ON  fi~CompanyCode        = header~CompanyCode
        AND fi~FiscalYear         = header~FiscalYear
        AND fi~AccountingDocument = header~AccountingDocument
      FIELDS DISTINCT
             item~SalesDocument             AS sales_order,
             header~BillingDocument         AS billing_document,
             header~AccountingDocument      AS accounting_document,
             fi~PostingDate                 AS invoice_posting_date,
             fi~AmountInTransactionCurrency AS invoice_amount
      WHERE item~SalesDocument               IN @lr_sales_order
        AND header~SDDocumentCategory         = 'M'
        AND header~BillingDocumentIsCancelled = @abap_false
        AND fi~FinancialAccountType           = 'D'
      INTO TABLE @DATA(lt_found).

    " SO 1 ใบมี invoice ใบเดียวและบรรทัด D บรรทัดเดียว
    " ถ้าเจอซ้ำจะเก็บแถวแรกไว้ ไม่ dump
    LOOP AT lt_found ASSIGNING FIELD-SYMBOL(<lfs_found>).
      INSERT CORRESPONDING #( <lfs_found> ) INTO TABLE rt_result.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_zari002_master_data~find_unknown_billing_documents.

    DATA lr_billing TYPE RANGE OF zif_zari002_master_data=>ty_billing_document.

    IF it_billing_document IS INITIAL.
      RETURN.
    ENDIF.

    lr_billing = VALUE #( FOR <lfs_doc> IN it_billing_document
                        ( sign = 'I' option = 'EQ' low = <lfs_doc> ) ).

    SELECT FROM I_BillingDocument WITH PRIVILEGED ACCESS
      FIELDS BillingDocument AS billing_document
      WHERE BillingDocument IN @lr_billing
      INTO TABLE @DATA(lt_existing).

    LOOP AT it_billing_document ASSIGNING FIELD-SYMBOL(<lfs_billing>).
      IF NOT line_exists( lt_existing[ billing_document = <lfs_billing> ] ).
        INSERT <lfs_billing> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_zari002_master_data~find_unknown_accounting_docs.

    DATA lr_company_code TYPE RANGE OF zif_zari002_master_data=>ty_company_code.
    DATA lr_document     TYPE RANGE OF zif_zari002_master_data=>ty_acc_doc_key-accounting_document.
    DATA lr_fiscal_year  TYPE RANGE OF zif_zari002_master_data=>ty_fiscal_year.

    IF it_acc_doc_key IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT it_acc_doc_key ASSIGNING FIELD-SYMBOL(<lfs_key>).

      IF NOT line_exists( lr_company_code[ low = <lfs_key>-company_code ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_key>-company_code ) TO lr_company_code.
      ENDIF.

      IF NOT line_exists( lr_document[ low = <lfs_key>-accounting_document ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_key>-accounting_document ) TO lr_document.
      ENDIF.

      IF NOT line_exists( lr_fiscal_year[ low = <lfs_key>-fiscal_year ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_key>-fiscal_year ) TO lr_fiscal_year.
      ENDIF.

    ENDLOOP.

    " range แยกกันจะได้แถวไขว้กันมาเกินได้ จึงต้องเทียบทั้ง 3 ตัวอีกรอบ
    SELECT FROM I_JournalEntry WITH PRIVILEGED ACCESS
      FIELDS CompanyCode        AS company_code,
             AccountingDocument AS accounting_document,
             FiscalYear         AS fiscal_year
      WHERE CompanyCode        IN @lr_company_code
        AND AccountingDocument IN @lr_document
        AND FiscalYear         IN @lr_fiscal_year
      INTO TABLE @DATA(lt_existing).

    LOOP AT it_acc_doc_key ASSIGNING <lfs_key>.
      IF NOT line_exists( lt_existing[ company_code        = <lfs_key>-company_code
                                       accounting_document = <lfs_key>-accounting_document
                                       fiscal_year         = <lfs_key>-fiscal_year ] ).
        INSERT <lfs_key> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
