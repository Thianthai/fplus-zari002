CLASS zcl_zari002_json DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      ty_request TYPE zcl_zari002_http=>ty_request,
      ty_payment TYPE zcl_zari002_http=>ty_payment,
      ty_item    TYPE zcl_zari002_http=>ty_item,
      tt_item    TYPE zcl_zari002_http=>tt_item.

    "! แปลง JSON payload เป็น structure ของ table
    "! ชื่อ field แปลงอัตโนมัติจาก PascalCase เป็น snake_case ด้วย pascal_case_to_underscore
    CLASS-METHODS parse_json_request
      IMPORTING iv_body    TYPE string
      EXPORTING es_request TYPE ty_request
      RAISING   zcx_zari002_error.

    "! แปลงชื่อ field snake_case ของ table เป็นชื่อ JSON PascalCase
    CLASS-METHODS to_json_name
      IMPORTING iv_field         TYPE string
      RETURNING VALUE(rv_result) TYPE string.

  PRIVATE SECTION.

    CLASS-METHODS to_internal_date
      IMPORTING iv_value         TYPE string
      RETURNING VALUE(rv_result) TYPE d.

ENDCLASS.


CLASS zcl_zari002_json IMPLEMENTATION.

  METHOD parse_json_request.

    DATA ls_request TYPE ty_request.

    TRY.
        xco_cp_json=>data->from_string( iv_body
          )->apply( VALUE #( ( xco_cp_json=>transformation->pascal_case_to_underscore ) )
          )->write_to( REF #( ls_request ) ).

      CATCH cx_root INTO DATA(lo_error).
        RAISE EXCEPTION TYPE zcx_zari002_error
          EXPORTING iv_msgv1 = |JSON parse failed: { lo_error->get_text( ) }|.
    ENDTRY.

    LOOP AT ls_request-payments ASSIGNING FIELD-SYMBOL(<lfs_payment>).
      <lfs_payment>-posting_date = to_internal_date( <lfs_payment>-posting_date ).
      <lfs_payment>-issue_date   = to_internal_date( <lfs_payment>-issue_date ).
      <lfs_payment>-due_on       = to_internal_date( <lfs_payment>-due_on ).

      LOOP AT <lfs_payment>-items ASSIGNING FIELD-SYMBOL(<lfs_item>).
        <lfs_item>-invoice_posting_date = to_internal_date( <lfs_item>-invoice_posting_date ).
        <lfs_item>-sale_submit_date     = to_internal_date( <lfs_item>-sale_submit_date ).
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD to_internal_date.

    IF iv_value IS INITIAL.
      RETURN.
    ENDIF.

    rv_result = replace( val = iv_value sub = `-` with = `` occ = 0 ).
    rv_result = replace( val = iv_value sub = `/` with = `` occ = 0 ).
    rv_result = replace( val = iv_value sub = `.` with = `` occ = 0 ).

  ENDMETHOD.


  METHOD to_json_name.

    CHECK iv_field IS NOT INITIAL.

    SPLIT to_lower( iv_field ) AT `_` INTO TABLE DATA(lt_part).

    LOOP AT lt_part ASSIGNING FIELD-SYMBOL(<lfs_part>).
      IF <lfs_part> IS INITIAL.
        CONTINUE.
      ENDIF.
      rv_result = |{ rv_result }| &&
                  |{ to_upper( substring( val = <lfs_part> len = 1 ) ) }| &&
                  |{ substring( val = <lfs_part> off = 1 ) }|.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
