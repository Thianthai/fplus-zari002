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



CLASS ZCL_ZARI002_SPIKE IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    " ปิดไว้ เพราะ purge_all ลบข้อมูลทั้ง ztar_i002_pymt และ ztar_i002_item โดยไม่มีเงื่อนไข
    " ห้ามเปิดบน client ที่มีข้อมูลจริง
*    purge_all( out ).

    out->write( |ZCL_ZARI002_SPIKE: purge_all is disabled| ).

  ENDMETHOD.


  METHOD purge_all.

*    DELETE FROM ztar_i002_pymt.
*    DELETE FROM ztar_i002_item.
*
*    COMMIT WORK.
*
*    io_out->write( |--- all 2 tables purged ---| ).

  ENDMETHOD.
ENDCLASS.
