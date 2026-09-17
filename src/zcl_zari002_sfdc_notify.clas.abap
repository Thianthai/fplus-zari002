CLASS zcl_zari002_sfdc_notify DEFINITION
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
    "! OAuth 2.0 token ถูกใส่โดย platform ผ่าน communication arrangement — ไม่ต้องขอเอง
    METHODS notify
      IMPORTING it_result TYPE tt_result.

    "! พิสูจน์ว่า arrangement + OAuth ใช้ได้ โดยไม่ต้องยิง payload จริง
    "! GET /services/data/ ของ Salesforce ตอบ 200 เมื่อ token ถูกต้อง · 401 = client id/secret ผิด
    "! คืน 0 เมื่อต่อไม่ถึงเลย (destination ไม่มี / host ผิด / certificate)
    METHODS check_connection
      RETURNING VALUE(rv_status) TYPE i.

  PRIVATE SECTION.

    CONSTANTS:
      gc_comm_scenario TYPE sxco_cds_object_name VALUE 'ZCS_PAYMENT_RESULT',
      gc_service_id    TYPE c LENGTH 40          VALUE 'ZARI002_PAYMENT_RESULT_REST',
      "! ⬜ mock — รอ spec ของ data API จาก SFDC
      gc_path_result   TYPE string               VALUE '/services/apexrest/PaymentResult',
      "! endpoint มาตรฐานของ Salesforce สำหรับเช็ค token — ไม่ใช่ของโปรเจกต์
      gc_path_ping     TYPE string               VALUE '/services/data/'.

    "! สร้าง HTTP client ผ่าน arrangement — จุดเดียวที่รู้จัก scenario / service id
    METHODS create_client
      RETURNING VALUE(ro_client) TYPE REF TO if_web_http_client
      RAISING   cx_http_dest_provider_error
                cx_web_http_client_error.

ENDCLASS.


CLASS zcl_zari002_sfdc_notify IMPLEMENTATION.

  METHOD build_payload.

    rv_result = xco_cp_json=>data->from_abap( it_result
                  )->apply( VALUE #( ( xco_cp_json=>transformation->underscore_to_pascal_case ) )
                  )->to_string( ).

  ENDMETHOD.


  METHOD create_client.

    DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                             comm_scenario = gc_comm_scenario
                             service_id    = gc_service_id ).

    ro_client = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

  ENDMETHOD.


  METHOD notify.

    IF it_result IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_client)  = create_client( ).
        DATA(lo_request) = lo_client->get_http_request( ).

        lo_request->set_uri_path( gc_path_result ).
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


  METHOD check_connection.

    TRY.
        DATA(lo_client) = create_client( ).
        lo_client->get_http_request( )->set_uri_path( gc_path_ping ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>get ).
        rv_status = lo_response->get_status( )-code.

        lo_client->close( ).

      CATCH cx_root.
        rv_status = 0.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
