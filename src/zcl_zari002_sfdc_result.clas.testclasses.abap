"! ทดสอบการประกอบ payload และอ่าน response โดยไม่ต่อไปที่ Salesforce
CLASS ltc_sfdc_result DEFINITION FINAL
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    METHODS payload_uses_sobject_names FOR TESTING.
    METHODS success_maps_to_word       FOR TESTING.
    METHODS failed_maps_to_word        FOR TESTING.
    METHODS no_body_key_when_empty     FOR TESTING.
    METHODS message_is_escaped         FOR TESTING.

    METHODS parse_201_is_success       FOR TESTING.
    METHODS parse_201_keeps_record_id  FOR TESTING.
    METHODS parse_400_takes_first_err  FOR TESTING.
    METHODS parse_garbage_is_parse_err FOR TESTING.

    "! record ตัวอย่างสำหรับทดสอบ payload
    METHODS sample
      IMPORTING iv_status        TYPE c DEFAULT 'S'
                iv_message       TYPE string DEFAULT `All payments saved successfully`
                iv_request_body  TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE zcl_zari002_sfdc_result=>ty_record.

ENDCLASS.


CLASS ltc_sfdc_result IMPLEMENTATION.

  METHOD sample.
    rs_result = VALUE #( interface    = zcl_zari002_sfdc_result=>gc_interface_payment
                         reference_id = 'SF0000000000000001'
                         status       = iv_status
                         message      = iv_message
                         request_body = iv_request_body ).
  ENDMETHOD.


  METHOD payload_uses_sobject_names.

    DATA(lv_json) = zcl_zari002_sfdc_result=>build_payload( sample( ) ).

    " ชื่อ field ต้องเป็นของ sObject เป๊ะ
    " transformation อัตโนมัติจะได้ InterfaceC ซึ่ง SFDC ไม่รู้จัก
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_json CS `"Interface__c":"Payment Response"` ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_json CS `"Reference_Id__c":"SF0000000000000001"` ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_json CS `"Direction__c":"Inbound"` ) ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( lv_json CS `InterfaceC` ) ).

  ENDMETHOD.


  METHOD success_maps_to_word.
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( zcl_zari002_sfdc_result=>build_payload( sample( iv_status = 'S' ) )
                     CS `"Status__c":"Success"` )
      msg = 'picklist ของ SFDC รับคำเต็ม ไม่ใช่ S' ).
  ENDMETHOD.


  METHOD failed_maps_to_word.

    DATA(lv_json) = zcl_zari002_sfdc_result=>build_payload(
                      sample( iv_status  = 'E'
                              iv_message = `Cheque number is required, Issue date is required` ) ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_json CS `"Status__c":"Failed"` ) ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lv_json CS `"Message__c":"Cheque number is required, Issue date is required"` )
      msg = 'Failed ต้องมี Message__c' ).

  ENDMETHOD.


  METHOD no_body_key_when_empty.

    " Request_Body__c เป็น optional ZARI002 ไม่ส่ง key ต้องไม่โผล่เลย
    cl_abap_unit_assert=>assert_false(
      act = xsdbool( zcl_zari002_sfdc_result=>build_payload( sample( ) ) CS `Request_Body__c` ) ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( zcl_zari002_sfdc_result=>build_payload( sample( iv_request_body = `{"fi_document":"1"}` ) )
                     CS `"Request_Body__c":` )
      msg = 'ZARI003 จะส่ง request_body ต้องโผล่เมื่อมีค่า' ).

  ENDMETHOD.


  METHOD message_is_escaped.

    " ข้อความอาจมีเครื่องหมายคำพูดจากค่าที่ส่งเข้ามา builder ต้อง escape ไม่งั้น JSON พัง
    DATA(lv_json) = zcl_zari002_sfdc_result=>build_payload(
                      sample( iv_status = 'E' iv_message = `Value "abc" is not a date` ) ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_json CS `\"abc\"` ) ).

  ENDMETHOD.


  METHOD parse_201_is_success.

    DATA(ls_result) = zcl_zari002_sfdc_result=>parse_response(
                        iv_json        = `{"id":"a5iAz0000004PJBIA2","success":true,"errors":[]}`
                        iv_http_status = 201 ).

    cl_abap_unit_assert=>assert_equals( exp = abap_true act = ls_result-success ).
    cl_abap_unit_assert=>assert_initial( act = ls_result-error_code ).

  ENDMETHOD.


  METHOD parse_201_keeps_record_id.

    cl_abap_unit_assert=>assert_equals(
      exp = 'a5iAz0000004PJBIA2'
      act = zcl_zari002_sfdc_result=>parse_response(
              iv_json        = `{"id":"a5iAz0000004PJBIA2","success":true,"errors":[]}`
              iv_http_status = 201 )-record_id
      msg = 'id ของ log record ที่ SFDC สร้างต้องอ่านเก็บไว้ได้' ).

  ENDMETHOD.


  METHOD parse_400_takes_first_err.

    DATA(ls_result) = zcl_zari002_sfdc_result=>parse_response(
      iv_json        = `[{"errorCode":"REQUIRED_FIELD_MISSING",` &&
                       `"message":"Required fields are missing: [Interface__c]",` &&
                       `"fields":["Interface__c"]}]`
      iv_http_status = 400 ).

    cl_abap_unit_assert=>assert_equals( exp = abap_false act = ls_result-success ).
    cl_abap_unit_assert=>assert_equals( exp = 'REQUIRED_FIELD_MISSING' act = ls_result-error_code ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_result-error_message ).

  ENDMETHOD.


  METHOD parse_garbage_is_parse_err.

    " ปลายทางตอบอะไรที่ไม่ใช่รูปแบบที่รู้จัก เช่น หน้า HTML ของ proxy
    DATA(ls_result) = zcl_zari002_sfdc_result=>parse_response( iv_json        = `<html>502</html>`
                                                               iv_http_status = 502 ).

    cl_abap_unit_assert=>assert_equals( exp = abap_false act = ls_result-success ).
    cl_abap_unit_assert=>assert_equals( exp = zcl_zari002_sfdc_result=>gc_err_parse
                                        act = ls_result-error_code ).

  ENDMETHOD.

ENDCLASS.
