CLASS zcl_zari003_sfdc_notify DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      "! 1 บรรทัดต่อ 1 item ตาม contract ของ SFDC
      BEGIN OF ty_result,
        salesforce_id      TYPE ztar_i002_pymt-salesforce_id,
        salesforce_item_id TYPE ztar_i002_item-salesforce_item_id,
        status             TYPE c LENGTH 1,
        error_message      TYPE c LENGTH 200,
      END OF ty_result,
      tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    CONSTANTS:
      "! SAP รับข้อมูลเข้า table สำเร็จ
      gc_status_success TYPE c LENGTH 1 VALUE 'S',
      "! SAP ไม่รับข้อมูล — ดู error_message
      gc_status_error   TYPE c LENGTH 1 VALUE 'E'.

    "! สร้าง JSON payload — แยกออกมาเพื่อให้ unit test ได้โดยไม่ต้องต่อเน็ต
    "! ชื่อ field แปลงเป็น PascalCase ด้วย transformation ตัวเดียวกับที่ ZCL_ZARI002_JSON ใช้
    CLASS-METHODS build_payload
      IMPORTING it_result        TYPE tt_result
      RETURNING VALUE(rv_result) TYPE string.

    "! ยิงผลกลับไป SFDC — fire and forget ตามที่ตกลง (ไม่เก็บสถานะ ไม่ retry)
    "! ยิงไม่สำเร็จต้องไม่ทำให้ request ของ ZARI002 พัง
    METHODS notify
      IMPORTING it_result TYPE tt_result.

  PRIVATE SECTION.

    CONSTANTS:
      "! ⬜ ยังไม่มีของจริง — รอ config ขา outbound ของ ARI003
      gc_comm_scenario TYPE sxco_cds_object_name VALUE 'ZARI003_OUT_CSCEN',
      gc_service_id    TYPE c LENGTH 40          VALUE 'ZARI003_OUT_REST'.

ENDCLASS.


CLASS zcl_zari003_sfdc_notify IMPLEMENTATION.

  METHOD build_payload.

    rv_result = xco_cp_json=>data->from_abap( it_result
                  )->apply( VALUE #( ( xco_cp_json=>transformation->underscore_to_pascal_case ) )
                  )->to_string( ).

  ENDMETHOD.


  METHOD notify.

    IF it_result IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                                 comm_scenario = gc_comm_scenario
                                 service_id    = gc_service_id ).

        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

        DATA(lo_request) = lo_client->get_http_request( ).
        lo_request->set_header_field( i_name  = 'Content-Type'
                                      i_value = 'application/json' ).
        lo_request->set_text( build_payload( it_result ) ).

        lo_client->execute( if_web_http_client=>post ).
        lo_client->close( ).

      CATCH cx_root.
*       fire and forget — ยิงไม่สำเร็จก็ปล่อย ไม่ให้กระทบ request ของ ZARI002
*       ⚠️ แลกกับการที่ไม่มีใครรู้ว่ามันล้ม และ retry ไม่ได้ (ตกลงไว้ 2026-08-31)
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
