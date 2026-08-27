# ZARI002 — Object List

รายชื่อ repository object ทั้งหมด + ไฟล์ที่จะเกิดใน repo
(`⬜` = ยังไม่สร้าง · `🟨` = ส่ง code ให้ใน chat แล้ว รอผู้ใช้สร้าง/activate บน tenant · `✅` = activate + push ขึ้น repo แล้ว)

> **ABAP object ทุกตัวในเอกสารนี้ผู้ใช้เป็นคนสร้างใน ADT และ push เอง** — Claude ส่ง code ให้ทาง chat
> ไม่เขียนไฟล์ ABAP ลง repo (ดู `CLAUDE.md` §Git) คอลัมน์ "ไฟล์" คือ path ที่ abapGit จะ serialize ไปลง

## Package

ทุก object ลง package **`ZARI002`** ตัวเดียว ไม่มี sub-package · abapGit ผูกที่ `ZARI002` แล้ว

| Package | Folder | Description | Status |
|---------|--------|-------------|--------|
| `ZARI002` | `src/` | Incoming Payments (API) | ✅ |

`.abapgit.xml` ที่ tenant serialize มาใช้ `STARTING_FOLDER = /src/` + `FOLDER_LOGIC = FULL`
เนื่องจาก `ZARI002` เป็น top package ที่ link ไว้และไม่มี sub-package ไฟล์จึงลง `src/` ตรง ๆ
(ถ้าวันหน้าเพิ่ม sub-package ไฟล์ของมันจะไปอยู่ `src/<ชื่อ package เต็ม>/`)

## DDIC

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZD_STATUS` | Domain (`N`/`S`/`W`/`E`) | `src/zd_status.doma.xml` | 0 | ✅ |
| `ZE_STATUS` | Data element | `src/ze_status.dtel.xml` | 0 | ✅ |
| `ZTAR_I002_PYMT` | Table — payment header | `src/ztar_i002_pymt.tabl.xml` | 0 | ✅ |
| `ZTAR_I002_ITEM` | Table — payment item | `src/ztar_i002_item.tabl.xml` | 0 | ✅ |
| `ZTAR_I002_PYMT~SFI` | Unique secondary index (`client` + `salesforce_id`) | อยู่ใน `ztar_i002_pymt.tabl.xml` | 2 | ⬜ |
| `ZARI002` | Message class | `src/zari002.msag.xml` | 2 | ⬜ |

> `ZD_STATUS` / `ZE_STATUS` เป็น object กลาง **จงใจไม่ใส่ RICEFW ID ในชื่อ** เพื่อให้ RICEFW อื่น reuse ได้
> `ZTAR_I002_*` ใช้ชื่อที่ผู้ใช้ออกแบบไว้เดิม ไม่เปลี่ยนตาม pattern `ZR_`/`ZC_` ของ project

## Core logic

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZCX_ZARI002_ERROR` | Exception class | `src/zcx_zari002_error.clas.abap` | 2 | ⬜ |
| `ZIF_ZARI002_MD_CHECK` | Interface — อ่าน master data (mock ได้) | `src/zif_zari002_md_check.intf.abap` | 4 | ⬜ |
| `ZCL_ZARI002_MD_CHECK` | Class — implementation จริงบน released CDS view | `src/zcl_zari002_md_check.clas.abap` | 4 | ⬜ |
| `ZCL_ZARI002_VALIDATOR` | Class — validation กลุ่ม format/mandatory/consistency | `src/zcl_zari002_validator.clas.abap` | 4 | ⬜ |

ทุก class มีไฟล์คู่: `*.clas.xml` (metadata) + `*.clas.testclasses.abap` (ABAP Unit)

## RAP business object

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZR_ZARI002` | CDS root view entity (payment header) | `src/zr_zari002.ddls.asddls` | 3 | ⬜ |
| `ZI_ZARI002_ITEM` | CDS interface view entity (item) | `src/zi_zari002_item.ddls.asddls` | 3 | ⬜ |
| `ZR_ZARI002` | Behavior definition (managed, strict 2) | `src/zr_zari002.bdef.asbdef` | 3 | ⬜ |
| `ZBP_R_ZARI002` | Behavior pool (`lhc_Payment`, `lhc_Item`) | `src/zbp_r_zari002.clas.abap` | 3 | ⬜ |
| `ZC_ZARI002` | CDS projection view (payment header) | `src/zc_zari002.ddls.asddls` | 5 | ⬜ |
| `ZC_ZARI002_ITEM` | CDS projection view (item) | `src/zc_zari002_item.ddls.asddls` | 5 | ⬜ |
| `ZC_ZARI002` | Behavior projection (`use create;`) | `src/zc_zari002.bdef.asbdef` | 5 | ⬜ |

## Service

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZAPI_ZARI002` | Service definition (Web API) | `src/zapi_zari002.srvd.srvdsrv` | 5 | ⬜ |
| `ZAPI_ZARI002_O4` | Service binding (OData V4, A2X) | `src/zapi_zari002_o4.srvb.xml` | 5 | ⬜ |

Entity set ที่ 3rd-party เห็น: **`Payment`** และ **`PaymentItem`**
(ตั้งผ่าน `expose ... as ...` ใน service definition — ชื่อ CDS ภายในไม่รั่วออกไปที่ API contract)

## Configuration (ไม่ใช่ repository object — ไม่เข้า repo)

| สิ่งที่ต้องทำ | ที่ไหน | Phase | Status |
|---|---|-------|--------|
| Communication Scenario `ZARI002_CSCEN` | ADT | 6 | ⬜ |
| Communication System | Fiori app | 6 | ⬜ |
| Communication User | Fiori app | 6 | ⬜ |
| Communication Arrangement | Fiori app | 6 | ⬜ |

## Object ที่ตัดสินใจไม่ทำ

| Object | เหตุผล |
|--------|--------|
| Draft table | เป็น API ไม่มี UI → ไม่ต้องมี draft |
| Number range object | key เป็น UUID (early numbering) |
| Authorization object `Z_ZARI002` | ใช้ `authorization master ( global )` + คุมสิทธิ์ที่ communication arrangement |
| Data element ของ field อื่น ๆ | table ใช้ built-in type ตรง ๆ → label ไปอยู่ที่ `@EndUserText.label` ใน CDS |
| Log table | reject ทั้ง request ไม่บันทึกอะไร → ถ้าต้องการ audit trail ค่อยพิจารณาเพิ่ม (`01_architecture.md` §8) |
