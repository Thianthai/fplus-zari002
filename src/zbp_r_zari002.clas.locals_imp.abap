CLASS lhc_Payment DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR Payment RESULT result.

    METHODS setPaymentDefaults FOR DETERMINE ON SAVE
       keys FOR Payment~setPaymentDefaults.

    METHODS setPaymentMethodCode FOR DETERMINE ON SAVE
       keys FOR Payment~setPaymentMethodCode.

    METHODS validateAmountFormat FOR VALIDATE ON SAVE
       keys FOR Payment~validateAmountFormat.

    METHODS validateAmountPaidTotal FOR VALIDATE ON SAVE
       keys FOR Payment~validateAmountPaidTotal.

    METHODS validateChequeBankBranch FOR VALIDATE ON SAVE
       keys FOR Payment~validateChequeBankBranch.

    METHODS validateChequeFields FOR VALIDATE ON SAVE
       keys FOR Payment~validateChequeFields.

    METHODS validateCompanyCode FOR VALIDATE ON SAVE
       keys FOR Payment~validateCompanyCode.

    METHODS validateDates FOR VALIDATE ON SAVE
       keys FOR Payment~validateDates.

    METHODS validateGLAccount FOR VALIDATE ON SAVE
       keys FOR Payment~validateGLAccount.

    METHODS validateItemDuplicate FOR VALIDATE ON SAVE
       keys FOR Payment~validateItemDuplicate.

    METHODS validateMandatory FOR VALIDATE ON SAVE
       keys FOR Payment~validateMandatory.

    METHODS validateNumberOfItems FOR VALIDATE ON SAVE
       keys FOR Payment~validateNumberOfItems.

    METHODS validatePaymentMethod FOR VALIDATE ON SAVE
       keys FOR Payment~validatePaymentMethod.

    METHODS validatePaymentTotal FOR VALIDATE ON SAVE
       keys FOR Payment~validatePaymentTotal.

    METHODS validateSalesforceId FOR VALIDATE ON SAVE
       keys FOR Payment~validateSalesforceId.

ENDCLASS.

CLASS lhc_Payment IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD setPaymentDefaults.
  ENDMETHOD.

  METHOD setPaymentMethodCode.
  ENDMETHOD.

  METHOD validateAmountFormat.
  ENDMETHOD.

  METHOD validateAmountPaidTotal.
  ENDMETHOD.

  METHOD validateChequeBankBranch.
  ENDMETHOD.

  METHOD validateChequeFields.
  ENDMETHOD.

  METHOD validateCompanyCode.
  ENDMETHOD.

  METHOD validateDates.
  ENDMETHOD.

  METHOD validateGLAccount.
  ENDMETHOD.

  METHOD validateItemDuplicate.
  ENDMETHOD.

  METHOD validateMandatory.
  ENDMETHOD.

  METHOD validateNumberOfItems.
  ENDMETHOD.

  METHOD validatePaymentMethod.
  ENDMETHOD.

  METHOD validatePaymentTotal.
  ENDMETHOD.

  METHOD validateSalesforceId.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS setItemDefaults FOR DETERMINE ON SAVE
       keys FOR Item~setItemDefaults.

    METHODS validateArOpenItem FOR VALIDATE ON SAVE
       keys FOR Item~validateArOpenItem.

    METHODS validateCustomerCode FOR VALIDATE ON SAVE
       keys FOR Item~validateCustomerCode.

    METHODS validateItemMandatory FOR VALIDATE ON SAVE
       keys FOR Item~validateItemMandatory.

    METHODS validateSalesforceItemId FOR VALIDATE ON SAVE
       keys FOR Item~validateSalesforceItemId.

ENDCLASS.

CLASS lhc_Item IMPLEMENTATION.

  METHOD setItemDefaults.
  ENDMETHOD.

  METHOD validateArOpenItem.
  ENDMETHOD.

  METHOD validateCustomerCode.
  ENDMETHOD.

  METHOD validateItemMandatory.
  ENDMETHOD.

  METHOD validateSalesforceItemId.
  ENDMETHOD.

ENDCLASS.
