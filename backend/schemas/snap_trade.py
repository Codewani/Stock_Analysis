from pydantic import BaseModel


class ConnectionRequest(BaseModel):
    broker: str
    custom_redirect: str | None = "https://snaptrade.com"
    immediate_redirect: bool = True
    reconnect: str = ""
    show_close_button: bool = True
    dark_mode: bool = True
    connection_portal_version: str = "v4"