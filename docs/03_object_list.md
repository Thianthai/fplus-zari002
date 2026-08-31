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
| `ZD_REQUEST_STATUS` | Domain (`N`/`C`/`R`/`E`) — transaction status | `src/zd_request_status.doma.xml` | 4 | ✅ |
| `ZE_REQUEST_STATUS` | Data element | `src/ze_request_status.dtel.xml` | 4 | ✅ |
| `ZD_RESPONSE_STATUS` | Domain (`S`/`W`/`E`) — result status ส่งกลับ SFDC | `src/zd_response_status.doma.xml` | 4 | ✅ |
| `ZE_RESPONSE_STATUS` | Data element | `src/ze_response_status.dtel.xml` | 4 | ✅ |
| `ZARI002` | Message class (34 messages) | `src/zari002.msag.xml` | 2 | ✅ |

> **Index ไม่ใช่ไฟล์แยก** — abapGit ฝัง `DD12V` / `DD17V` ไว้ใน `.tabl.xml` ของ table เจ้าของ
> `ZD_*` / `ZE_*` เป็น object กลาง **จงใจไม่ใส่ RICEFW ID ในชื่อ** เพื่อให้ RICEFW อื่น reuse ได้
> `ZD_STATUS` / `ZE_STATUS` ชุดเดิมถูกลบไปแล้ว (2026-08-28) — ไม่มี object กำพร้าค้าง
> `ZTAR_I002_*` ใช้ชื่อที่ผู้ใช้ออกแบบไว้เดิม ไม่เปลี่ยนตาม pattern `ZR_`/`ZC_` ของ project

## Core logic

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZCX_ZARI002_ERROR` | Exception class | `src/zcx_zari002_error.clas.abap` | 2 | ✅ |
| `ZIF_ZARI002_MASTER_DATA` | Interface — อ่าน master data (mock ได้) | `src/zif_zari002_master_data.intf.abap` | 3 | ✅ |
| `ZCL_ZARI002_MASTER_DATA` | Class — implementation จริงบน released CDS view | `src/zcl_zari002_master_data.clas.abap` | 3 | ✅ |
| `ZCL_ZARI002_VALIDATOR` | Class — validation format/mandatory/consistency + constant แปลง payment method · 31 unit test | `src/zcl_zari002_validator.clas.abap` | 3 | 🟨 รอเปลี่ยน signature |
| `ZCL_ZARI002_SFDC_NOTIFY` | Class — ยิง callback ไป SFDC | `src/zcl_zari002_sfdc_notify.clas.abap` | 3 | ⬜ |
| `ZCL_ZARI002_PROCESSOR` | Class — flow 5 ขั้น (parse → normalize → validate → save → callback) | `src/zcl_zari002_processor.clas.abap` | 3 | ⬜ |

ทุก class มีไฟล์คู่: `*.clas.xml` (metadata) + `*.clas.testclasses.abap` (ABAP Unit)

## HTTP service

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZCL_ZARI002_HTTP` | Handler — `IF_HTTP_SERVICE_EXTENSION` | `src/zcl_zari002_http.clas.abap` | 4 | ⬜ |
| `ZARI002_HTTP` | HTTP Service repository object | รอดูจากของจริง | 4 | ⬜ |

> **RAP ถูกถอดออกทั้งหมดเมื่อ 2026-08-31** — CDS view, behavior definition, behavior pool,
> projection view และ behavior projection ถูกลบ · เหตุผลอยู่ใน `01_architecture.md` §2

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
| RAP BO ทั้งชุด | ถอดออก 2026-08-31 — ไม่มี OData แล้วจึงไม่มีเหตุผลที่ต้องมี BO (`01_architecture.md` §2) |
| Number range object | key เป็น UUID — `ZCL_ZARI002_PROCESSOR` สร้างเอง |
| Authorization object `Z_ZARI002` | คุมสิทธิ์ที่ communication arrangement |
| Data element ของ field อื่น ๆ | table ใช้ built-in type ตรง ๆ → label ไปอยู่ที่ `@EndUserText.label` ใน CDS |
| Log table | reject ทั้ง request ไม่บันทึกอะไร → ถ้าต้องการ audit trail ค่อยพิจารณาเพิ่ม (`01_architecture.md` §8) |

> `ZCL_ZARI002_SPIKE_MD` และ `ZCL_ZARI002_SPIKE_EML` เป็น throwaway — **ลบทิ้งเมื่อจบ Phase 4** · ไม่มี unit test เพราะเป็น manual probe
