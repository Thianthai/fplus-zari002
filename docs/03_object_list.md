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
| `ZARI002` | Message class (**39 messages** — `000`–`012` · `100`–`118` · `200`–`205` · `900`) | `src/zari002.msag.xml` | 2 | ✅ |
| `ZARI002/206` | Message `Item &1: document &2 already cleared or reversed` — **ยังไม่ได้สร้าง** สร้างพร้อมตอนเติม logic ของ OQ-08 | `src/zari002.msag.xml` | — | ⬜ |

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
| `ZCL_ZARI002_VALIDATOR` | Class — validation format/mandatory/consistency + constant แปลง payment method · 31 unit test | `src/zcl_zari002_validator.clas.abap` | 3 | ✅ |
| `ZCL_ZARI002_JSON` | Class — parse payload + แปลงชื่อ field 2 ทาง · 9 unit test | `src/zcl_zari002_json.clas.abap` | 3 | ✅ |
| `ZCL_ZARI002_SFDC_NOTIFY` | Class — ยิง callback ไป SFDC · **draft ไม่มี test** รอ OQ-17 | `src/zcl_zari002_sfdc_notify.clas.abap` | 3 | 🟨 |
| `ZCL_ZARI002_PROCESSOR` | Class — flow 5 ขั้น (parse → normalize → validate → save → callback) · 9 unit test | `src/zcl_zari002_processor.clas.abap` | 3 | ✅ |

ทุก class มีไฟล์คู่: `*.clas.xml` (metadata) + `*.clas.testclasses.abap` (ABAP Unit)

## HTTP service

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZCL_ZARI002_HTTP` | Handler — `IF_HTTP_SERVICE_EXTENSION` | `src/zcl_zari002_http.clas.abap` | 4 | ✅ |
| `ZARI002_INCOMING_PYMT` | HTTP Service | `src/zari002_incoming_pymt.http.xml` | 4 | ✅ |

> **RAP ถูกถอดออกทั้งหมดเมื่อ 2026-08-31** — CDS view, behavior definition, behavior pool,
> projection view และ behavior projection ถูกลบ · เหตุผลอยู่ใน `01_architecture.md` §2

## Connectivity

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZCS_INCOMING_PYMT` | Communication Scenario (inbound) | `src/zcs_incoming_pymt.sco1.xml` | 5 | ✅ |
| `ZARI002_INCOMING_PYMT_HTTP` | Inbound Service | `src/zari002_incoming_pymt_http.sco2.xml` | 5 | ✅ |
| *(hash)* | Service authorization ที่ระบบสร้างให้ | `src/44b031caa406301c29d6134c05f9baht.sush.xml` | 5 | ✅ |
| Communication Scenario (outbound) | สำหรับยิง callback | — | 5 | ⬜ OQ-17 |

> **Communication Scenario เป็น repository object** จึงขึ้น git ด้วย · ส่วน Communication
> System / User / Arrangement เป็น config ใน Fiori **ไม่ขึ้น git** ต้องตั้งใหม่เองในทุกระบบ

## Configuration (ไม่ใช่ repository object — ไม่เข้า repo)

| สิ่งที่ต้องทำ | ที่ไหน | Phase | Status |
|---|---|-------|--------|
| Communication System `SBPA_DEV` | Fiori app | 5 | ✅ |
| Communication User `SBPA_DEV` | Fiori app | 5 | ✅ |
| Communication Arrangement `ZCS_INCOMING_PYMT` (client 100) | Fiori app | 5 | ✅ |
| Communication System + Arrangement ขา outbound | Fiori app | 5 | ⬜ |

