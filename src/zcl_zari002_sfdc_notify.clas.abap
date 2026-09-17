CLASS zcl_zari002_sfdc_notify DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      "! 1 record = 1 Integration_Log__c บน Salesforce
      "! class นี้ไม่รู้จัก ZARI002 — ผู้เรียกกำหนด interface กับ request_body เอง
      "! ZARI003 ใช้ตัวเดียวกันได้โดยส่ง interface ของตัวเองและใส่เลข FI doc ใน request_body
      BEGIN OF ty_record,
        interface    TYPE string,
        reference_id TYPE ztar_i002_pymt-salesforce_id,
        status       TYPE c LENGTH 1,
        message      TYPE string,
        request_body TYPE string,
      END OF ty_record.

    CONSTANTS:
      "! SAP รับข้อมูลเข้า table สำเร็จ → Status__c = Success
      gc_status_success TYPE c LENGTH 1 VALUE 'S',
      "! SAP ไม่รับข้อมูล → Status__c = Failed · Message__c บังคับ
      gc_status_error   TYPE c LENGTH 1 VALUE 'E',
      "! ค่า Interface__c ของ ZARI002 — ผู้เรียกส่งเข้ามาเอง ไม่ใช่ default
      gc_interface_payment TYPE string VALUE 'Payment Response',
      "! HTTP status ที่ Salesforce ตอบเมื่อ insert สำเร็จ · ไม่มีเคส 200
      gc_http_created   TYPE i VALUE 201.

    "! สร้าง JSON ให้ตรงชื่อ field ของ sObject (`Interface__c` ฯลฯ)
    "! ใช้ builder เพราะ transformation อัตโนมัติจะทำ `__c` พัง · escape ข้อความให้ด้วย
    "! `Request_Body__c` ไม่ส่ง key ถ้าว่าง — field เป็น optional
    CLASS-METHODS build_payload
      IMPORTING is_record        TYPE ty_record
      RETURNING VALUE(rv_result) TYPE string.

    "! POST 1 record ไป Integration_Log__c ผ่าน communication arrangement
    "! คืน HTTP status ที่ได้ (201 = สำเร็จ) · คืน 0 เมื่อต่อไม่ถึงเลย
    "! ไม่โยน exception — ผู้เรียกตัดสินเองว่าจะทำอะไรกับผล
    METHODS notify
      IMPORTING is_record             TYPE ty_record
      RETURNING VALUE(rv_http_status) TYPE i.

    "! พิสูจน์ว่า arrangement + OAuth ใช้ได้ โดยไม่ต้องยิง payload จริง
    "! GET /services/data/ ตอบ 200 เมื่อ token ถูกต้อง · 401 = client id/secret ผิด · 0 = ต่อไม่ถึง
    METHODS check_connection
      RETURNING VALUE(rv_status) TYPE i.

  PRIVATE SECTION.

    CONSTANTS:
      gc_comm_scenario TYPE sxco_cds_object_name VALUE 'ZCS_PAYMENT_RESULT',
      gc_service_id    TYPE c LENGTH 40          VALUE 'ZARI002_PAYMENT_RESULT_REST',
      "! Salesforce standard sObject API — spec IN #4
      gc_path_log      TYPE string VALUE '/services/data/v66.0/sobjects/Integration_Log__c',
      "! endpoint มาตรฐานของ Salesforce สำหรับเช็ค token — ไม่ใช่ของโปรเจกต์
      gc_path_ping     TYPE string VALUE '/services/data/',
      "! Message__c รับได้ 4000 ตัว — ตัดก่อนส่ง ไม่งั้นได้ STRING_TOO_LONG ทั้ง record
      gc_message_max   TYPE i VALUE 4000.

    "! สร้าง HTTP client ผ่าน arrangement — จุดเดียวที่รู้จัก scenario / service id
    METHODS create_client
      RETURNING VALUE(ro_client) TYPE REF TO if_web_http_client
      RAISING   cx_http_dest_provider_error
                cx_web_http_client_error.

ENDCLASS.


CLASS zcl_zari002_sfdc_notify IMPLEMENTATION.

  METHOD build_payload.

    DATA(lo_builder) = xco_cp_json=>data->builder( ).

    lo_builder->begin_object(
      )->add_member( 'Interface__c'    )->add_string( is_record-interface
      )->add_member( 'Reference_Id__c' )->add_string( CONV #( is_record-reference_id )
      )->add_member( 'Direction__c'    )->add_string( 'Inbound'
      )->add_member( 'Status__c'       )->add_string( COND #( WHEN is_record-status = gc_status_success
                                                              THEN 'Success' ELSE 'Failed' ) ).

*   Message__c บังคับเฉพาะ Failed แต่ส่งทั้ง 2 กรณีเพื่อให้ Success มีข้อความอ่านได้ในหน้า SFDC
    IF is_record-message IS NOT INITIAL.
      lo_builder->add_member( 'Message__c' )->add_string( substring( val = is_record-message
                                                                     len = nmin( val1 = strlen( is_record-message )
                                                                                 val2 = gc_message_max ) ) ).
    ENDIF.

    IF is_record-request_body IS NOT INITIAL.
      lo_builder->add_member( 'Request_Body__c' )->add_string( is_record-request_body ).
    ENDIF.

    rv_result = lo_builder->end_object( )->get_data( )->to_string( ).

  ENDMETHOD.


  METHOD create_client.

    DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                             comm_scenario = gc_comm_scenario
                             service_id    = gc_service_id ).

    ro_client = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

  ENDMETHOD.


  METHOD notify.

    TRY.
        DATA(lo_client)  = create_client( ).
        DATA(lo_request) = lo_client->get_http_request( ).

        lo_request->set_uri_path( gc_path_log ).
        lo_request->set_header_field( i_name  = 'Content-Type'
                                      i_value = 'application/json' ).
        lo_request->set_text( build_payload( is_record ) ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).
        rv_http_status = lo_response->get_status( )-code.

        lo_client->close( ).

      CATCH cx_root.
*       ต่อไม่ถึง / arrangement ไม่มี — คืน 0 ให้ผู้เรียกบันทึกว่าไม่ได้ส่ง
        rv_http_status = 0.
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
