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

*   จำกัดขอบเขตด้วย 2 range แล้วค่อยจับคู่ในหน่วยความจำ
*   เพราะ SQL เทียบคู่ (company_code, gl_account) พร้อมกันไม่ได้
    LOOP AT it_gl_key ASSIGNING FIELD-SYMBOL(<lfs_key>).

      IF NOT line_exists( lr_company_code[ low = <lfs_key>-company_code ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_key>-company_code )
               TO lr_company_code.
      ENDIF.

      IF NOT line_exists( lr_gl_account[ low = <lfs_key>-gl_account ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_key>-gl_account )
               TO lr_gl_account.
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


  METHOD zif_zari002_master_data~find_unknown_pymt_methods.

    DATA lr_country        TYPE RANGE OF zif_zari002_master_data=>ty_country.
    DATA lr_payment_method TYPE RANGE OF zif_zari002_master_data=>ty_payment_method.

    IF it_payment_method_key IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT it_payment_method_key ASSIGNING FIELD-SYMBOL(<lfs_pm>).

      IF NOT line_exists( lr_country[ low = <lfs_pm>-country ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_pm>-country )
               TO lr_country.
      ENDIF.

      IF NOT line_exists( lr_payment_method[ low = <lfs_pm>-payment_method ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <lfs_pm>-payment_method )
               TO lr_payment_method.
      ENDIF.

    ENDLOOP.

    SELECT FROM I_PaymentMethod
      FIELDS Country       AS country,
             PaymentMethod AS payment_method
      WHERE Country       IN @lr_country
        AND PaymentMethod IN @lr_payment_method
      INTO TABLE @DATA(lt_existing).

    LOOP AT it_payment_method_key ASSIGNING <lfs_pm>.
      IF NOT line_exists( lt_existing[ country        = <lfs_pm>-country
                                       payment_method = <lfs_pm>-payment_method ] ).
        INSERT <lfs_pm> INTO TABLE rt_result.
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

    SELECT FROM I_Customer
      FIELDS Customer AS customer
      WHERE Customer IN @lr_customer
      INTO TABLE @DATA(lt_existing).

    LOOP AT it_customer ASSIGNING FIELD-SYMBOL(<lfs_c>).
      IF NOT line_exists( lt_existing[ customer = <lfs_c> ] ).
        INSERT <lfs_c> INTO TABLE rt_result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
