@EndUserText.label: 'Incoming Payments - Item'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity ZI_ZARI002_ITEM
  as select from ztar_i002_item
  association to parent ZR_ZARI002 as _Payment
    on $projection.PaymentUUID = _Payment.PaymentUUID
{
  key item_uuid             as ItemUUID,

      payment_uuid          as PaymentUUID,
      salesforce_item_id    as SalesforceItemId,
      customer_code         as CustomerCode,
      billing_note_no       as BillingNoteNo,
      accounting_document   as AccountingDocument,
      billing_document      as BillingDocument,
      invoice_posting_date  as InvoicePostingDate,
      currency              as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      invoice_amount        as InvoiceAmount,
      @Semantics.amount.currencyCode: 'Currency'
      amount_paid           as AmountPaid,

      partial_amount        as PartialAmount,
      sale_submit_date      as SaleSubmitDate,
      reject_reason         as RejectReason,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Payment
}
