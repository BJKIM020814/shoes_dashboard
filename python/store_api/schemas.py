from pydantic import BaseModel, Field, model_validator


class PickupScan(BaseModel):
    qr: str | None = Field(default=None, min_length=1, max_length=200, description="카메라로 읽은 QR 문자열")
    code: str | None = Field(default=None, pattern=r"^\d{6}$", description="QR 대신 입력하는 6자리 난수")

    @model_validator(mode="after")
    def _one_of(self):
        if bool(self.qr) == bool(self.code):
            raise ValueError("qr 또는 code 중 하나만 보내 주세요.")
        return self


class PickupConfirm(PickupScan):
    staff_id: str = Field(min_length=1, max_length=45, description="Firebase employeeId")


class ReturnCreate(BaseModel):
    customer_id: str = Field(max_length=45)
    p_code: str = Field(max_length=45)
    reason: str = Field(min_length=1, max_length=45)
    staff_id: str = Field(max_length=45)


class RefundRequest(BaseModel):
    staff_id: str = Field(max_length=45)


class StockAdjust(BaseModel):
    quantity: int = Field(ge=0, description="조정 후 재고 수량")


class ShipmentReceive(BaseModel):
    staff_id: str = Field(max_length=45)
    product_id: str | None = Field(default=None, max_length=45, description="입고 상품 코드(주면 매장 재고에 발송수량을 더함)")


class StoreInfoUpdate(BaseModel):
    open_time: str | None = Field(default=None, pattern=r"^\d{2}:\d{2}$")
    close_time: str | None = Field(default=None, pattern=r"^\d{2}:\d{2}$")
    photo_url: str | None = Field(default=None, max_length=500)
    manager: str | None = Field(default=None, max_length=45)
    dealer_number: str | None = Field(default=None, max_length=45)
    address: str | None = Field(default=None, max_length=45)
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)
