CLASS lhc_PaymentLog DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR PaymentLog RESULT result.

ENDCLASS.

CLASS lhc_PaymentLog IMPLEMENTATION.

  METHOD get_global_authorizations.

*   Log rows are written by ZCL_ZARI002_PROCESSOR with direct INSERT.
*   This BO is read-only: the monitor displays, it never edits.
*   No operation is declared, so there is nothing to allow or deny here.

  ENDMETHOD.

ENDCLASS.
