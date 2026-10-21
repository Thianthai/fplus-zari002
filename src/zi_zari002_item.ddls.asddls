@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Incoming Payments - Item Posting Result'
@Metadata.ignorePropagatedAnnotations: true
// อ่าน ZTAR_I002_ITEM อย่างเดียว ให้หน้า log เห็น reject reason ล่าสุดที่ ZARE002 เขียน
// reject_reason ใน ITMLOG เป็นค่าที่ copy ไว้ตอนรับข้อมูล จึงว่างเสมอ
define view entity ZI_ZARI002_ITEM
  as select from ztar_i002_item
{
  key item_uuid     as ItemUUID,

      reject_reason as RejectReason
}
