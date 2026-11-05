"""可插拔的第三方登录渠道。每个渠道把客户端拿到的凭证（id_token / 授权码 / 验证码）校验成一个稳定的 subject。

接新渠道：写一个 LoginProvider 子类，在 PROVIDERS 里注册。
- apple：校验 Sign in with Apple 的 identityToken（JWT，用 Apple 公钥验签，aud = Bundle ID），subject = sub
- google：校验 Google ID token（JWT），subject = sub
- wechat：用 code 换 access_token + openid / unionid，subject = unionid
- sms：先发验证码（另一个接口 + 限流），校验 手机号 + 验证码，subject = 手机号的哈希
这些需要各平台的密钥，现在只占位（返回 501）。本地开发用 mock 渠道走通完整流程。
"""

from .config import get_settings
from .errors import ApiError


class LoginProvider:
    name = ""

    def verify(self, credential: str) -> str:
        raise NotImplementedError


class MockProvider(LoginProvider):
    """开发用：凭证写成 "mock:<用户名>"，用户名就是 subject。正式环境（TRIBE_ENV=prod）自动关闭。"""

    name = "mock"

    def verify(self, credential: str) -> str:
        if not credential.startswith("mock:") or not 1 <= len(credential) - 5 <= 64:
            raise ApiError(401, "bad_credential", "mock 凭证格式是 mock:<用户名>")
        return credential[5:]


class NotConfigured(LoginProvider):
    def __init__(self, name: str):
        self.name = name

    def verify(self, credential: str) -> str:
        raise ApiError(501, "provider_not_configured", "%s 登录还没有接入" % self.name)


PROVIDERS: dict[str, LoginProvider] = {
    "mock": MockProvider(),
    "apple": NotConfigured("apple"),
    "google": NotConfigured("google"),
    "wechat": NotConfigured("wechat"),
    "sms": NotConfigured("sms"),
}


def get(name: str) -> LoginProvider:
    p = PROVIDERS.get(name)
    if p is None:
        raise ApiError(400, "unknown_provider", "没有这个登录渠道")
    if name == "mock" and not get_settings().enable_mock_provider:
        raise ApiError(403, "provider_disabled", "mock 登录只在开发环境可用")
    return p
