CLASS zcl_zari002_master_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_zari002_master_data.
ENDCLASS.



CLASS zcl_zari002_master_data IMPLEMENTATION.

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

ENDCLASS.
