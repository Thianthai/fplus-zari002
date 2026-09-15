CLASS zcl_zari002_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_zari002_util IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    SELECT SINGLE FROM ztar_i002_pymt
    FIELDS payment_uuid
    WHERE payment_document_no = '1000000109'
    INTO @DATA(lv_payment_uuid).

    IF sy-subrc = 0.
      DELETE FROM ztar_i002_pymt WHERE payment_uuid = @lv_payment_uuid.
      IF sy-subrc <> 0.
        ROLLBACK WORK.
        RETURN.
      ENDIF.

      DELETE FROM ztar_i002_item WHERE payment_uuid = @lv_payment_uuid.
      IF sy-subrc = 0.
        COMMIT WORK.
      ENDIF.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
