CLASS zcl_zari002_http DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

    " Request Type -----------------------------------------------------
    TYPES:
      BEGIN OF ty_item,
        salesforce_item_id   TYPE ztar_i002_item-salesforce_item_id,
        customer_code        TYPE ztar_i002_item-customer_code,
        billing_note_no      TYPE ztar_i002_item-billing_note_no,
        accounting_document  TYPE ztar_i002_item-accounting_document,
        billing_document     TYPE ztar_i002_item-billing_document,
        invoice_posting_date TYPE string,
        invoice_amount       TYPE ztar_i002_item-invoice_amount,
        amount_paid          TYPE ztar_i002_item-amount_paid,
        partial_amount       TYPE ztar_i002_item-partial_amount,
        sale_submit_date     TYPE string,
      END OF ty_item,
      tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY,

      BEGIN OF ty_payment,
        salesforce_id              TYPE ztar_i002_pymt-salesforce_id,
        payment_document_no        TYPE ztar_i002_pymt-payment_document_no,
        number_of_items_in_payment TYPE ztar_i002_pymt-number_of_items_in_payment,
        company_code               TYPE ztar_i002_pymt-company_code,
        posting_date               TYPE string,
        gl_account                 TYPE ztar_i002_pymt-gl_account,
        payment_method             TYPE ztar_i002_pymt-payment_method,
        cheque_no                  TYPE ztar_i002_pymt-cheque_no,
        issue_date                 TYPE string,
        due_on                     TYPE string,
        cheque_bank_branch         TYPE ztar_i002_pymt-cheque_bank_branch,
        rounding_diff              TYPE ztar_i002_pymt-rounding_diff,
        advance_payment            TYPE ztar_i002_pymt-advance_payment,
        fees                       TYPE ztar_i002_pymt-fees,
        payment_amount             TYPE ztar_i002_pymt-payment_amount,
        items                      TYPE tt_item,
      END OF ty_payment,
      tt_payment TYPE STANDARD TABLE OF ty_payment WITH EMPTY KEY,

      BEGIN OF ty_request,
        request_id TYPE string,
        payments   TYPE tt_payment,
      END OF ty_request.

  PRIVATE SECTION.

    " Response Type ----------------------------------------------------
    TYPES:
      BEGIN OF ty_error,
        code               TYPE string,
        message            TYPE string,
        salesforce_id      TYPE string,
        salesforce_item_id TYPE string,
        field              TYPE string,
      END OF ty_error,
      tt_error TYPE STANDARD TABLE OF ty_error WITH EMPTY KEY,

      BEGIN OF ty_response,
        request_id TYPE string,
        accepted   TYPE i,
        rejected   TYPE i,
        errors     TYPE tt_error,
      END OF ty_response.

    " Handle Methods ---------------------------------------------------
    METHODS handle_get
      CHANGING co_http_response TYPE REF TO if_web_http_response.

    METHODS handle_post
      IMPORTING io_http_request  TYPE REF TO if_web_http_request
      CHANGING  co_http_response TYPE REF TO if_web_http_response.

ENDCLASS.


CLASS zcl_zari002_http IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.

    CASE request->get_method( ).
      WHEN 'GET'.
        handle_get( CHANGING co_http_response = response ).

      WHEN 'POST'.
        handle_post( EXPORTING io_http_request  = request
                     CHANGING  co_http_response = response ).

      WHEN OTHERS.
        response->set_status( i_code   = 405
                              i_reason = 'Method Not Allowed' ).
        RETURN.

    ENDCASE.

  ENDMETHOD.

  METHOD handle_get.

    DATA ls_request TYPE ty_request.

    ls_request-request_id = 'YYYYMMDD_hhmmss'.
    DO 2 TIMES.
      APPEND INITIAL LINE TO ls_request-payments ASSIGNING FIELD-SYMBOL(<lfs_payment>).
      <lfs_payment>-salesforce_id = |SalesforceID-{ sy-index }|.
      DO 2 TIMES.
        APPEND INITIAL LINE TO <lfs_payment>-items ASSIGNING FIELD-SYMBOL(<lfs_item>).
        <lfs_item>-salesforce_item_id = |SalesforceItemID-{ sy-index }|.
      ENDDO.
    ENDDO.

    co_http_response->set_header_field( i_name  = 'Content-Type'
                                        i_value = 'application/json' ).

    co_http_response->set_status( i_code   = 200
                                  i_reason = 'OK' ).

    co_http_response->set_text( xco_cp_json=>data->from_abap( ls_request
                                )->apply( VALUE #( ( xco_cp_json=>transformation->underscore_to_pascal_case ) )
                                )->to_string( ) ).

  ENDMETHOD.

  METHOD handle_post.


    DATA(ls_result) = NEW zcl_zari002_processor( )->process( io_http_request->get_text( ) ).

    DATA(ls_response) = VALUE ty_response( request_id = |{ ls_result-request_id }|
                                           accepted   = COND #( WHEN ls_result-success = abap_true THEN ls_result-items )
                                           rejected   = COND #( WHEN ls_result-success = abap_false THEN ls_result-items )
                                           errors     = VALUE #( FOR <lfs_error> IN ls_result-errors
                                                               ( code               = |ZARI002/{ <lfs_error>-msgno }|
                                                                 message            = <lfs_error>-msgtx
                                                                 salesforce_id      = <lfs_error>-salesforce_id
                                                                 salesforce_item_id = <lfs_error>-salesforce_item_id
                                                                 field              = <lfs_error>-field ) ) ).

    co_http_response->set_header_field( i_name  = 'Content-Type'
                                        i_value = 'application/json' ).

    co_http_response->set_status( i_code   = COND #( WHEN ls_result-success = abap_true THEN 200 ELSE 400 )
                                  i_reason = COND #( WHEN ls_result-success = abap_true THEN 'OK' ELSE 'Bad Request' ) ).

    co_http_response->set_text( xco_cp_json=>data->from_abap( ls_response
                                )->apply( VALUE #( ( xco_cp_json=>transformation->underscore_to_pascal_case ) )
                                )->to_string( ) ).

  ENDMETHOD.

ENDCLASS.
