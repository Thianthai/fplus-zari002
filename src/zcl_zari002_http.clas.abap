CLASS zcl_zari002_http DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_error,
        code    TYPE string,
        message TYPE string,
        field   TYPE string,
        item    TYPE string,
      END OF ty_error,
      tt_error TYPE STANDARD TABLE OF ty_error WITH EMPTY KEY,

      "! ชื่อ component เป็น snake_case แล้วให้ transformation แปลงเป็น PascalCase
      "! ตอน serialize — วิธีเดียวกับ ZCL_ZARI002_JSON ใช้ขาเข้า
      BEGIN OF ty_response,
        batch_id TYPE string,
        accepted TYPE i,
        rejected TYPE i,
        errors   TYPE tt_error,
      END OF ty_response.

ENDCLASS.


CLASS zcl_zari002_http IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.

    IF to_upper( request->get_method( ) ) <> 'POST'.
      response->set_status( i_code   = 405
                            i_reason = 'Method Not Allowed' ).
      RETURN.
    ENDIF.

    DATA(ls_outcome) = NEW zcl_zari002_processor( )->process( request->get_text( ) ).

    DATA(ls_response) = VALUE ty_response(
      batch_id = |{ ls_outcome-batch_id }|
      accepted = COND #( WHEN ls_outcome-success = abap_true  THEN ls_outcome-items )
      rejected = COND #( WHEN ls_outcome-success = abap_false THEN ls_outcome-items )
      errors   = VALUE #( FOR <lfs_err> IN ls_outcome-errors
                          ( code    = |ZARI002/{ <lfs_err>-msgno }|
                            message = <lfs_err>-text
                            field   = <lfs_err>-field
                            item    = |{ <lfs_err>-item }| ) ) ).

    response->set_status( i_code   = COND #( WHEN ls_outcome-success = abap_true THEN 200 ELSE 400 )
                          i_reason = COND #( WHEN ls_outcome-success = abap_true THEN 'OK'
                                             ELSE 'Bad Request' ) ).

    response->set_header_field( i_name  = 'Content-Type'
                                i_value = 'application/json' ).

    response->set_text( xco_cp_json=>data->from_abap( ls_response
                          )->apply( VALUE #( ( xco_cp_json=>transformation->underscore_to_pascal_case ) )
                          )->to_string( ) ).

  ENDMETHOD.

ENDCLASS.
