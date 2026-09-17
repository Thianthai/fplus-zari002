CLASS ltc_notify DEFINITION FINAL
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    METHODS payload_uses_sobject_names FOR TESTING.
    METHODS success_maps_to_word       FOR TESTING.
    METHODS failed_maps_to_word        FOR TESTING.
    METHODS no_body_key_when_empty     FOR TESTING.
    METHODS message_is_escaped         FOR TESTING.

    METHODS sample
      IMPORTING iv_status        TYPE c DEFAULT 'S'
                iv_message       TYPE string DEFAULT `All payments saved successfully`
                iv_request_body  TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE zcl_zari002_sfdc_notify=>ty_record.

ENDCLASS.


CLASS ltc_notify IMPLEMENTATION.

  METHOD sample.
    rs_result = VALUE #( interface    = zcl_zari002_sfdc_notify=>gc_interface_payment
                         reference_id = 'SF0000000000000001'
                         status       = iv_status
                         message      = iv_message
                         request_body = iv_request_body ).
  ENDMETHOD.


  METHOD payload_uses_sobject_names.

    DATA(lv_json) = zcl_zari002_sfdc_notify=>build_payload( sample( ) ).

*   ชื่อ field ต้องเป็นของ sObject เป๊ะ — transformation อัตโนมัติจะได้ InterfaceC ซึ่ง SFDC ไม่รู้จัก
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_json CS `"Interface__c":"Payment Response"` ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_json CS `"Reference_Id__c":"SF0000000000000001"` ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_json CS `"Direction__c":"Inbound"` ) ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( lv_json CS `InterfaceC` ) ).

  ENDMETHOD.


  METHOD success_maps_to_word.
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( zcl_zari002_sfdc_notify=>build_payload( sample( iv_status = 'S' ) )
                     CS `"Status__c":"Success"` )
      msg = 'picklist ของ SFDC รับคำเต็ม ไม่ใช่ S' ).
  ENDMETHOD.


  METHOD failed_maps_to_word.

    DATA(lv_json) = zcl_zari002_sfdc_notify=>build_payload(
                      sample( iv_status  = 'E'
                              iv_message = `Cheque number is required, Issue date is required` ) ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_json CS `"Status__c":"Failed"` ) ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( lv_json CS `"Message__c":"Cheque number is required, Issue date is required"` )
      msg = 'Failed ต้องมี Message__c' ).

  ENDMETHOD.


  METHOD no_body_key_when_empty.

*   Request_Body__c เป็น optional — ZARI002 ไม่ส่ง (D1-A) · key ต้องไม่โผล่เลย ไม่ใช่ส่งค่าว่าง
    cl_abap_unit_assert=>assert_false(
      act = xsdbool( zcl_zari002_sfdc_notify=>build_payload( sample( ) ) CS `Request_Body__c` ) ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( zcl_zari002_sfdc_notify=>build_payload( sample( iv_request_body = `{"fi_document":"1"}` ) )
                     CS `"Request_Body__c":` )
      msg = 'ZARI003 จะส่ง request_body — ต้องโผล่เมื่อมีค่า' ).

  ENDMETHOD.


  METHOD message_is_escaped.

*   msgtx มี " ได้ (เช่น ค่าที่ user ส่งมา) — builder ต้อง escape ไม่งั้น JSON พัง
    DATA(lv_json) = zcl_zari002_sfdc_notify=>build_payload(
                      sample( iv_status = 'E' iv_message = `Value "abc" is not a date` ) ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_json CS `\"abc\"` ) ).

  ENDMETHOD.

ENDCLASS.
