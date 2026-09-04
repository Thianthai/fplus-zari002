INTERFACE zif_zari002_master_data
  PUBLIC.

  TYPES:
    ty_company_code   TYPE ztar_i002_pymt-company_code,
    ty_gl_account     TYPE ztar_i002_pymt-gl_account,
    ty_payment_method TYPE ztar_i002_pymt-sap_payment_method,
    ty_currency       TYPE ztar_i002_pymt-currency,
    ty_customer       TYPE ztar_i002_item-customer_code,
    ty_country        TYPE c LENGTH 3,
    ty_bank           TYPE ztar_i002_pymt-cheque_bank_branch.

  TYPES:
    "! company code + ข้อมูลที่ derive ต่อได้
    BEGIN OF ty_company_code_info,
      company_code TYPE ty_company_code,
      currency     TYPE ty_currency,
      country      TYPE ty_country,
    END OF ty_company_code_info,

    "! GL account ผูกกับ company code เสมอ ตรวจแยกกันไม่ได้
    BEGIN OF ty_gl_key,
      company_code TYPE ty_company_code,
      gl_account   TYPE ty_gl_account,
    END OF ty_gl_key,

    "! payment method ผูกกับประเทศ
    BEGIN OF ty_payment_method_key,
      country        TYPE ty_country,
      payment_method TYPE ty_payment_method,
    END OF ty_payment_method_key,

    "! bank ผูกกับประเทศ เหมือน payment method
    BEGIN OF ty_bank_key,
      country TYPE ty_country,
      bank    TYPE ty_bank,
    END OF ty_bank_key.

  TYPES:
    tt_company_code       TYPE SORTED TABLE OF ty_company_code
                          WITH UNIQUE KEY table_line,
    tt_company_code_info  TYPE SORTED TABLE OF ty_company_code_info
                          WITH UNIQUE KEY company_code,
    tt_gl_key             TYPE SORTED TABLE OF ty_gl_key
                          WITH UNIQUE KEY company_code gl_account,
    tt_payment_method_key TYPE SORTED TABLE OF ty_payment_method_key
                          WITH UNIQUE KEY country payment_method,
    tt_customer           TYPE SORTED TABLE OF ty_customer
                          WITH UNIQUE KEY table_line,
    tt_bank_key           TYPE SORTED TABLE OF ty_bank_key
                          WITH UNIQUE KEY country bank.

  "! อ่าน currency และ country ของ company code
  "! ใช้ทั้งใน setPaymentDefaults (เอาค่าไปเติม) และ validateCompanyCode (เช็คว่ามีจริง)
  "! company code ที่ไม่มีจริง **จะไม่อยู่ในผลลัพธ์** — ผู้เรียกตรวจจากการที่มันหายไป
  METHODS get_company_codes
    IMPORTING it_company_code  TYPE tt_company_code
    RETURNING VALUE(rt_result) TYPE tt_company_code_info.

  "! คืน GL account ที่ **ไม่มีจริง** ใน company code นั้น
  METHODS find_unknown_gl_accounts
    IMPORTING it_gl_key        TYPE tt_gl_key
    RETURNING VALUE(rt_result) TYPE tt_gl_key.

  "! คืน payment method code ที่ **ไม่มีจริง** ในประเทศนั้น
  METHODS find_unknown_pymt_methods
    IMPORTING it_payment_method_key TYPE tt_payment_method_key
    RETURNING VALUE(rt_result)      TYPE tt_payment_method_key.

  "! คืน customer ที่ **ไม่มีจริง**
  METHODS find_unknown_customers
    IMPORTING it_customer      TYPE tt_customer
    RETURNING VALUE(rt_result) TYPE tt_customer.

  "! คืน bank ที่ **ไม่มีจริง** ในประเทศนั้น
  "! ค่าต้องตรงกับ I_Bank_2-BankInternalID เป๊ะ — field ไม่มี conversion routine
  "! จึงไม่ pad ให้ ต้นทางต้องส่งมาถูกเอง
  METHODS find_unknown_banks
    IMPORTING it_bank_key      TYPE tt_bank_key
    RETURNING VALUE(rt_result) TYPE tt_bank_key.

ENDINTERFACE.
