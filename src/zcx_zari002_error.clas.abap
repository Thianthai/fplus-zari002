CLASS zcx_zari002_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_t100_message.
    INTERFACES if_t100_dyn_msg.

    " message key เริ่มต้น — ZARI002/900 Unexpected error: &1
    CONSTANTS:
      BEGIN OF gc_unexpected_error,
        msgid TYPE symsgid      VALUE 'ZARI002',
        msgno TYPE symsgno      VALUE '900',
        attr1 TYPE scx_attrname VALUE 'GV_MSGV1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF gc_unexpected_error.

    DATA gv_msgv1 TYPE string READ-ONLY.
    DATA gv_msgv2 TYPE string READ-ONLY.
    DATA gv_msgv3 TYPE string READ-ONLY.
    DATA gv_msgv4 TYPE string READ-ONLY.

    "! สร้าง exception พร้อม message จาก message class ZARI002
    "! @parameter textid   | message key — ไม่ระบุจะใช้ ZARI002/900
    "! @parameter previous | exception ก่อนหน้า สำหรับ chaining
    "! @parameter iv_msgv1 | ค่าแทน placeholder &1
    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous TYPE REF TO cx_root           OPTIONAL
        iv_msgv1 TYPE string                   OPTIONAL
        iv_msgv2 TYPE string                   OPTIONAL
        iv_msgv3 TYPE string                   OPTIONAL
        iv_msgv4 TYPE string                   OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_zari002_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    super->constructor( previous = previous ).

    gv_msgv1 = iv_msgv1.
    gv_msgv2 = iv_msgv2.
    gv_msgv3 = iv_msgv3.
    gv_msgv4 = iv_msgv4.

    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = gc_unexpected_error.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
