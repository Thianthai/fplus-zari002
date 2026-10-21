@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Incoming Payments - Item Log'
@Metadata.allowExtensions: true
define view entity ZC_ZARI002_ITEM_LOG
  as projection on ZI_ZARI002_ITEM_LOG
{
  key ItemUUID,
      PaymentUUID,

      SalesforceItemId,
      CustomerCode,
      BillingNoteNo,
      AccountingDocument,
      BillingDocument,
      InvoicePostingDate,

      Currency,
      InvoiceAmount,
      AmountPaid,
      PartialAmount,
      SaleSubmitDate,

      // reject reason ล่าสุดจาก ZTAR_I002_ITEM
      // RejectReason ของ log เป็นค่าที่ copy ไว้ตอนรับข้อมูล จึงว่างเสมอ ไม่ดึงมาแสดง
      @EndUserText.label: 'Reject Reason'
      _Item.RejectReason as PostingRejectReason,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associations */
      _PaymentLog : redirected to parent ZC_ZARI002_PYMT_LOG
}
