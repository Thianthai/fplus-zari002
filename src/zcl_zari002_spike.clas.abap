CLASS zcl_zari002_spike DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .

  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS purge_all
      IMPORTING io_out TYPE REF TO if_oo_adt_classrun_out.
ENDCLASS.



CLASS zcl_zari002_spike IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    purge_all( out ).

  ENDMETHOD.

  METHOD purge_all.

    DELETE FROM ztar_i002_pymt.
    DELETE FROM ztar_i002_item.

    COMMIT WORK.

    io_out->write( |--- all 2 tables purged ---| ).

  ENDMETHOD.

ENDCLASS.
