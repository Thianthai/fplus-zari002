CLASS zcl_zari002_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_ZARI002_UTIL IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    SELECT FROM ztar_i002_pymt
    FIELDS payment_uuid
    WHERE payment_document_no IN ( '1000000101', '1000000109', '1000000110', '1000000111', '1000000112' )
    INTO TABLE @DATA(lt_header).

    LOOP AT lt_header INTO DATA(ls_header).

      DELETE FROM ztar_i002_pymt WHERE payment_uuid = @ls_header-payment_uuid.
      IF sy-subrc <> 0.
        ROLLBACK WORK.
        CONTINUE.
      ENDIF.

      DELETE FROM ztar_i002_item WHERE payment_uuid = @ls_header-payment_uuid.
      IF sy-subrc = 0.
        COMMIT WORK AND WAIT.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
