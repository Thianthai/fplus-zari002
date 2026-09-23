"! ส่งผลการรับข้อมูลกลับ Salesforce ราย payment ด้วย sObject API (Integration_Log__c)
"! ทุก call ขอ HTTP client จาก ZCL_UTILITY=>create_sfdc_client ซึ่งขอ token ใหม่และผูก Authorization: Bearer มาให้ใน HTTP header แล้ว
"! Client Secret อยู่ใน Communication System — ABAP จะมองเห็นแค่ access token
"! เรียกจาก ZCL_ZARI002_PROCESSOR ท้าย loop ของแต่ละ payment
"! ไม่โยน exception ทุก method คืนผลให้ caller ตรงๆ
"! ไม่ประกาศ FINAL เพราะ test double ของ processor สืบทอด class นี้เพื่อดักสิ่งที่จะส่ง
CLASS zcl_zari002_sfdc_result DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      "! 1 record = 1 Integration_Log__c บน Salesforce
      "! Caller กำหนด interface กับ request_body เอง
      "! ZARI002 ส่ง interface ของตัวเองแต่ไม่ใส่ request_body
      "! ZARI003 ใช้ตัวเดียวกันได้โดยส่ง interface ของตัวเองและใส่เลข FI Document ใน request_body
      BEGIN OF ty_record,
        interface    TYPE string,
        reference_id TYPE ztar_i002_pymt-salesforce_id,
        status       TYPE c LENGTH 1,
        message      TYPE string,
        request_body TYPE string,
      END OF ty_record,

      "! ผลของการส่ง 1 record — เอาไปเขียน log table ได้ตรงๆ
      "! record_id คือ id ของ Integration_Log__c ที่ Salesforce สร้างให้
      "! error_code จาก Salesforce (เช่น REQUIRED_FIELD_MISSING) หรือจาก class (NOT_REACHABLE / PARSE_ERROR / TOKEN_[code])
      BEGIN OF ty_result,
        http_status   TYPE i,
        success       TYPE abap_bool,
        record_id     TYPE string,
        error_code    TYPE string,
        error_message TYPE string,
      END OF ty_result.

    CONSTANTS:
      "! SAP รับข้อมูลเข้า table สำเร็จ
      "! Status__c = Success
      gc_status_success    TYPE c LENGTH 1 VALUE 'S',
      "! SAP ไม่รับข้อมูล
      "! Status__c = Failed
      gc_status_error      TYPE c LENGTH 1 VALUE 'E',
      "! ZARI002 Caller ส่งค่า Interface__c เข้ามาเอง ไม่ใช่ default
      gc_interface_payment TYPE string     VALUE 'Payment Response',
      "! HTTP status ที่ Salesforce ตอบเมื่อ insert สำเร็จ
      "! sObject API ไม่มีเคส 200 เพราะ insert ใหม่ทุกครั้ง
      gc_http_created      TYPE i          VALUE 201,

      "! error_code ของ class
      gc_err_not_reachable TYPE string     VALUE 'NOT_REACHABLE',
      gc_err_parse         TYPE string     VALUE 'PARSE_ERROR'.

    "! สร้าง JSON ให้ตรงชื่อ field ของ sObject (เช่น `Interface__c`)
    "! ใช้ builder เพราะ transformation อัตโนมัติจะทำ `__c` พัง และ escape ข้อความให้ด้วย
    "! `Request_Body__c` ไม่ส่ง key ถ้าว่าง (field เป็น optional)
    CLASS-METHODS build_payload
      IMPORTING is_record        TYPE ty_record
      RETURNING VALUE(rv_json)   TYPE string.

    "! อ่าน response ของ sObject API
    "! สำเร็จ = HTTP 201 และไม่มี errorCode ในbody
    "! ล้มเหลว = body เป็น array ของ error เอา errorCode/message ตัวแรก
    "! แยกออกมาสำหรับให้ทดสอบได้โดยไม่ต่อไปที่ Salesforce
    CLASS-METHODS parse_response
      IMPORTING iv_json          TYPE string
                iv_http_status   TYPE i
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! ขอ token สำเร็จ ยิง POST 1 ครั้งและอ่านผล
    "! ขอ token ไม่สำเร็จ คืน error_code TOKEN_[code] โดยไม่ยิง POST
    "! ต่อไม่ถึงคืน HTTP 0 + NOT_REACHABLE ให้ caller โดยตรง
    METHODS send
      IMPORTING is_record        TYPE ty_record
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! ทดสอบว่า Communication Arrangement + token ใช้ได้จริง โดยไม่ต้องยิง payload
    "! คืน 200 = ใช้ได้
    "! คืน 401 = Salesforce ไม่รับ token
    "! คืน 0 = ต่อไม่ถึง หรือขอ token ไม่ได้
    METHODS check_connection
      RETURNING VALUE(rv_status) TYPE i.

  PRIVATE SECTION.

    CONSTANTS:
      "! Salesforce standard sObject API
      "! Path ของ Communication Arrangement เป็น "/" ฝั่งนี้จึงต้องใส่ path เต็มเอง
      gc_path_log    TYPE string VALUE '/services/data/v66.0/sobjects/Integration_Log__c',
      "! Message__c รับได้ 4000 ตัว ตัดก่อนส่ง ไม่งั้นได้ STRING_TOO_LONG ทั้ง record
      gc_message_max TYPE i      VALUE 4000.

ENDCLASS.



CLASS zcl_zari002_sfdc_result IMPLEMENTATION.


  METHOD build_payload.

    DATA(lo_builder) = xco_cp_json=>data->builder( ).

    lo_builder->begin_object(
      )->add_member( 'Interface__c'    )->add_string( is_record-interface
      )->add_member( 'Reference_Id__c' )->add_string( CONV #( is_record-reference_id )
      )->add_member( 'Direction__c'    )->add_string( 'Inbound'
      )->add_member( 'Status__c'       )->add_string( COND #( WHEN is_record-status = gc_status_success
                                                              THEN 'Success' ELSE 'Failed' ) ).

    " Message__c บังคับเฉพาะ Failed แต่ส่งทั้ง 2 กรณีเพื่อให้ Success มีข้อความอ่านได้ในหน้า SFDC
    IF is_record-message IS NOT INITIAL.
      lo_builder->add_member( 'Message__c' )->add_string( substring( val = is_record-message
                                                                     len = nmin( val1 = strlen( is_record-message )
                                                                                 val2 = gc_message_max ) ) ).
    ENDIF.

    IF is_record-request_body IS NOT INITIAL.
      lo_builder->add_member( 'Request_Body__c' )->add_string( is_record-request_body ).
    ENDIF.

    rv_json = lo_builder->end_object( )->get_data( )->to_string( ).

  ENDMETHOD.


  METHOD parse_response.

    rs_result-http_status = iv_http_status.

    DATA lv_member TYPE string.

    TRY.
        DATA(lo_reader) = cl_sxml_string_reader=>create( cl_abap_conv_codepage=>create_out( )->convert( iv_json ) ).

        DO.
          DATA(lo_node) = lo_reader->read_next_node( ).

          IF lo_node IS INITIAL.
            EXIT.
          ENDIF.

          CASE lo_node->type.

            WHEN if_sxml_node=>co_nt_element_open.
              DATA(lo_open) = CAST if_sxml_open_element( lo_node ).

              CLEAR lv_member.
              LOOP AT lo_open->get_attributes( ) INTO DATA(lo_attribute).
                IF lo_attribute->qname-name = 'name'.
                  lv_member = lo_attribute->get_value( ).
                ENDIF.
              ENDLOOP.

            WHEN if_sxml_node=>co_nt_value.
              DATA(lv_value) = CAST if_sxml_value_node( lo_node )->get_value( ).

              CASE lv_member.
                WHEN 'id'.
                  rs_result-record_id = lv_value.

                  " body ตอนพังเป็น array เอา error ก้อนแรกเท่านั้น
                WHEN 'errorCode'.
                  IF rs_result-error_code IS INITIAL.
                    rs_result-error_code = lv_value.
                  ENDIF.
                WHEN 'message'.
                  IF rs_result-error_message IS INITIAL.
                    rs_result-error_message = lv_value.
                  ENDIF.
              ENDCASE.

              CLEAR lv_member.

          ENDCASE.
        ENDDO.

      CATCH cx_root.
        rs_result-success    = abap_false.
        rs_result-error_code = gc_err_parse.
        RETURN.
    ENDTRY.

    " สำเร็จ = 201 และไม่มี errorCode
    IF iv_http_status = gc_http_created AND rs_result-error_code IS INITIAL.
      rs_result-success = abap_true.
      RETURN.
    ENDIF.

    rs_result-success = abap_false.

    " ไม่ใช่ 201 แต่อ่าน errorCode ไม่เจอ แปลว่า body ไม่ใช่รูปแบบที่รู้จัก
    IF rs_result-error_code IS INITIAL.
      rs_result-error_code    = gc_err_parse.
      rs_result-error_message = substring( val = iv_json
                                           len = nmin( val1 = strlen( iv_json ) val2 = 100 ) ).
    ENDIF.

  ENDMETHOD.


  METHOD send.

    TRY.
        " ZCL_UTILITY ขอ token ใหม่ทุกครั้งแล้วใส่ Authorization: Bearer ให้แล้ว
        " เหตุผลคือ Salesforce ไม่ส่ง expires_in ทำให้ arrangement แบบ OAuth ถือ token ค้างจนได้ 401 ในวันถัดมา
        zcl_utility=>create_sfdc_client( IMPORTING eo_client = DATA(lo_client)
                                                   es_error  = DATA(ls_token_error) ).

        IF lo_client IS NOT BOUND.
          " ขอ token ไม่ได้ ไม่ได้ยิง POST เลย
          " ใส่ TOKEN_ นำหน้าเพื่อให้แยกออกจาก error ที่ Salesforce ตอบกลับมาตอนยิง record
          rs_result-http_status   = ls_token_error-http_status.
          rs_result-success       = abap_false.
          rs_result-error_code    = |TOKEN_{ ls_token_error-error_code }|.
          rs_result-error_message = ls_token_error-error_message.
          RETURN.
        ENDIF.

        DATA(lo_request) = lo_client->get_http_request( ).

        lo_request->set_uri_path( gc_path_log ).

        lo_request->set_header_field( i_name  = 'Content-Type'
                                      i_value = 'application/json' ).

        lo_request->set_text( build_payload( is_record ) ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).

        rs_result = parse_response( iv_json        = lo_response->get_text( )
                                    iv_http_status = lo_response->get_status( )-code ).

        lo_client->close( ).

      CATCH cx_root.
        " ต่อไม่ถึง หรือ Communication Arrangement พัง
        rs_result-http_status = 0.
        rs_result-success     = abap_false.
        rs_result-error_code  = gc_err_not_reachable.
    ENDTRY.

  ENDMETHOD.


  METHOD check_connection.

    " ยิง endpoint ที่ต้องใช้ token จริง ไม่ใช่ /services/data/ ที่ตอบ 200 แม้ token หมดอายุ
    rv_status = zcl_utility=>check_sfdc_connection( ).

  ENDMETHOD.

ENDCLASS.
