@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Incoming Payments - Posting Status'
@ObjectModel.resultSet.sizeCategory: #XS
// ข้อความของ posting status จาก fixed value ของ domain ZD_REQUEST_STATUS
// เพิ่มหรือแก้ข้อความที่ domain แล้วหน้าจอเปลี่ยนตามเอง ไม่ต้องแก้ view นี้
// key ต้องตรงกับ source ไม่งั้นได้ warning
// กรองภาษาเดียวแล้ว Status จึงไม่ซ้ำกัน association จาก ZI_ZARI002_PYMT ได้แถวเดียวเสมอ
// Status ใช้ value_low ตรงๆ ไม่ cast เพราะ cast ลงเหลือ 1 ตัวจะได้ warning
define view entity ZI_ZARI002_POST_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZD_REQUEST_STATUS' )
{
      @UI.hidden: true
  key domain_name    as DomainName,

      @UI.hidden: true
  key value_position as ValuePosition,

      @ObjectModel.text.element: [ 'StatusText' ]
      @EndUserText.label: 'Posting Status'
      value_low      as Status,

      @Semantics.text: true
      @EndUserText.label: 'Posting Status'
      text           as StatusText
}
where language = $session.system_language
