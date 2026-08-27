CLASS zcl_zari002_spike_md DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " ตรวจว่า released CDS view ที่ ZARI002 จะใช้ validate master data
    " ใช้ได้จริงบน tenant นี้ + ดึงค่าตัวอย่างไว้ทำ test payload
    " throwaway — ลบทิ้งเมื่อจบ Phase 4
    INTERFACES if_oo_adt_classrun.
ENDCLASS.


CLASS zcl_zari002_spike_md IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

*   --- 1) I_CompanyCode → validateCompanyCode -----------------------
    SELECT FROM I_CompanyCode
      FIELDS CompanyCode
      ORDER BY CompanyCode
      INTO TABLE @DATA(lt_company_code)
      UP TO 10 ROWS.

    out->write( |=== I_CompanyCode : { lines( lt_company_code ) } rows ===| ).
    out->write( lt_company_code ).

*   --- 2) I_GLAccountInCompanyCode → validateGLAccount ---------------
    SELECT FROM I_GLAccountInCompanyCode
      FIELDS CompanyCode, GLAccount
      ORDER BY CompanyCode, GLAccount
      INTO TABLE @DATA(lt_gl_account)
      UP TO 10 ROWS.

    out->write( |=== I_GLAccountInCompanyCode : { lines( lt_gl_account ) } rows ===| ).
    out->write( lt_gl_account ).

*   --- 3) I_Currency → validateCurrency ------------------------------
    SELECT FROM I_Currency
      FIELDS Currency
      WHERE Currency = 'THB'
      INTO TABLE @DATA(lt_currency)
      UP TO 10 ROWS.

    out->write( |=== I_Currency (THB) : { lines( lt_currency ) } rows ===| ).
    out->write( lt_currency ).

*   --- 4) I_PaymentMethod → validatePaymentMethod --------------------
    SELECT FROM I_PaymentMethod
      FIELDS Country, PaymentMethod
      ORDER BY Country, PaymentMethod
      INTO TABLE @DATA(lt_payment_method)
      UP TO 10 ROWS.

    out->write( |=== I_PaymentMethod : { lines( lt_payment_method ) } rows ===| ).
    out->write( lt_payment_method ).

*   --- 5) I_Customer → validateCustomerCode --------------------------
    SELECT FROM I_Customer
      FIELDS Customer
      ORDER BY Customer
      INTO TABLE @DATA(lt_customer)
      UP TO 10 ROWS.

    out->write( |=== I_Customer : { lines( lt_customer ) } rows ===| ).
    out->write( lt_customer ).

*   --- 6) I_CompanyCode: currency + country ที่จะใช้ derive ----------
    SELECT FROM I_CompanyCode
      FIELDS CompanyCode, Currency, Country
      ORDER BY CompanyCode
      INTO TABLE @DATA(lt_cc_detail)
      UP TO 10 ROWS.

    out->write( |=== I_CompanyCode detail ===| ).
    out->write( lt_cc_detail ).

*   --- 7) I_Bank_2 → validateChequeBankBranch ------------------------
    SELECT FROM I_Bank_2
      FIELDS BankCountry, BankInternalID
      ORDER BY BankCountry, BankInternalID
      INTO TABLE @DATA(lt_bank)
      UP TO 10 ROWS.

    out->write( |=== I_Bank_2 : { lines( lt_bank ) } rows ===| ).
    out->write( lt_bank ).

*   --- 8) payment method ที่มีจริงบน tenant --------------------------
    SELECT FROM I_PaymentMethod
      FIELDS Country, PaymentMethod
      WHERE Country = 'TH'
      ORDER BY PaymentMethod
      INTO TABLE @DATA(lt_pm_th)
      UP TO 50 ROWS.

    out->write( |=== I_PaymentMethod (TH) : { lines( lt_pm_th ) } rows ===| ).
    out->write( lt_pm_th ).

*   --- 9) payment method ทุก field เพื่อหา description --------------
    SELECT FROM I_PaymentMethod
      FIELDS *
      WHERE Country = 'TH'
      INTO TABLE @DATA(lt_pm_full)
      UP TO 30 ROWS.

    out->write( |=== I_PaymentMethod ทุก field ===| ).
    out->write( lt_pm_full ).

*   --- 10) GL account ที่ sample ใช้ (pad เป็น 10 หลักแล้ว) ---------
    SELECT FROM I_GLAccountInCompanyCode
      FIELDS CompanyCode, GLAccount
      WHERE CompanyCode = '2000'
        AND GLAccount IN ( '0011011214', '0011011211', '0011011201' )
      INTO TABLE @DATA(lt_gl_check).

    out->write( |=== GL ของ sample : เจอ { lines( lt_gl_check ) } จาก 3 ===| ).
    out->write( lt_gl_check ).

*   --- 11) 0040129 อยู่ใน I_Bank_2 จริงไหม -------------------------
    SELECT FROM I_Bank_2
      FIELDS BankCountry, BankInternalID
      WHERE BankCountry = 'TH'
        AND BankInternalID IN ( '004', '0040129' )
      INTO TABLE @DATA(lt_bank_check).

    out->write( |=== bank check : เจอ { lines( lt_bank_check ) } จาก 2 ===| ).
    out->write( lt_bank_check ).

  ENDMETHOD.

ENDCLASS.
