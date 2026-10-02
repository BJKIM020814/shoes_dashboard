from __future__ import annotations

import base64
import binascii
import hashlib
import json
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict


class Body(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)


def today():
    return datetime.now(ZoneInfo('Asia/Seoul')).date()


def dates(start, end):
    end = end or today()
    start = start or (end - timedelta(days=29))
    if start > end or (end - start).days > 730:
        raise HTTPException(422, '조회 기간은 시작일 ≤ 종료일, 최대 731일이어야 합니다.')
    return start, end, end + timedelta(days=1)


def encode_id(*parts):
    return base64.urlsafe_b64encode(json.dumps(parts, ensure_ascii=False, separators=(',', ':')).encode()).decode().rstrip('=')


def decode_id(value, kind):
    try:
        parts = json.loads(base64.b64decode(value + '=' * (-len(value) % 4), altchars=b'-_', validate=True))
        if not isinstance(parts, list) or len(parts) != 4 or parts[0] != kind:
            raise ValueError
        if not isinstance(parts[1], str) or not parts[1] or len(parts[1]) > 254:
            raise ValueError
        if kind == 'review' and not isinstance(parts[2], (str, int)):
            raise ValueError
        if kind == 'inquiry' and (type(parts[2]) is not int or parts[2] < 0):
            raise ValueError
        if type(parts[3]) is not int or parts[3] < 0:
            raise ValueError
        if encode_id(*parts) != value:
            raise ValueError
        return tuple(parts[1:])
    except (ValueError, TypeError, binascii.Error, UnicodeDecodeError) as exc:
        raise HTTPException(422, '잘못된 리소스 ID입니다. 목록 API가 반환한 id를 사용하세요.') from exc


def key(value):
    return hashlib.sha256(value.encode()).hexdigest()


def require(row):
    if row is None:
        raise HTTPException(404, '데이터를 찾을 수 없습니다.')
    return row
