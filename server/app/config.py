"""配置：全部来自环境变量或 server/.env（见 .env.example），代码里不写死密钥和地址。"""

from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

SERVER_DIR = Path(__file__).resolve().parent.parent
REPO_DIR = SERVER_DIR.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=str(SERVER_DIR / ".env"), env_prefix="TRIBE_", extra="ignore")

    replay_godot: str = ""
    replay_timeout_sec: int = 20

    # 运行环境：dev / test / prod。prod 下关掉 mock 登录渠道和 mock 支付。
    env: str = "dev"
    # SQLAlchemy 连接串。本地默认 SQLite；正式环境用 postgresql+psycopg://user:pass@host/db
    database_url: str = f"sqlite:///{(SERVER_DIR / 'tribe.db').as_posix()}"
    # 游戏配置目录（data/*.json），服务器和客户端读同一份
    data_dir: str = str(REPO_DIR / "data")
    # 经济 / 校验 / 热卖参数
    economy_config: str = str(SERVER_DIR / "config" / "economy.json")
    # token 签名无关：token 是随机串，库里只存 sha256(pepper + token)。pepper 必须在正式环境里换掉。
    token_pepper: str = "dev-pepper-change-me"
    token_ttl_days: int = 30
    # 剩余有效期少于这么多天时，客户端会自动续期
    token_renew_days: int = 7
    # 日期按 UTC+8（北京时间）零点换日
    day_utc_offset_hours: int = 8
    # 请求体上限（字节）
    max_body_bytes: int = 96 * 1024
    # 限流：每个玩家 / 每个 IP 每分钟最多多少个请求
    rate_player_per_min: int = 120
    rate_ip_per_min: int = 600
    # 转移码输错这么多次锁定 lock_minutes 分钟
    transfer_max_fails: int = 5
    transfer_lock_minutes: int = 15
    # 快照保留：最近 N 份 + 每天一份（保留 daily_days 天）
    backups_recent: int = 3
    backups_daily_days: int = 30
    # 老存档第一次连服务器时，服务器字段（货币、建造……）信一次客户端快照。上线迁移窗口过后关掉。
    allow_adopt: bool = True
    # 是否启用 mock 第三方登录 / mock 支付（只在 dev / test）
    enable_mock_provider: bool = True
    enable_mock_payment: bool = True
    # 日志级别、是否输出 JSON（正式环境 JSON，本地也可以开）
    log_level: str = "INFO"
    log_json: bool = True
    # 反向代理后面时信任 X-Forwarded-For 取真实 IP
    trust_forwarded: bool = False
    cors_origins: list[str] = Field(default_factory=list)
    # 异步联机活动（篝火竞速）配置；race_overrides 是调试用的覆盖（JSON），例如
    # TRIBE_RACE_OVERRIDES='{"cycle_sec": 600, "duration_sec": 480, "join_sec": 420, "fill_sec": 20}' 把场次缩短
    race_config: str = str(SERVER_DIR / "config" / "race.json")
    race_overrides: dict = Field(default_factory=dict)

    @property
    def is_prod(self) -> bool:
        return self.env == "prod"


@lru_cache
def get_settings() -> Settings:
    s = Settings()
    if s.is_prod:
        if s.token_pepper == "dev-pepper-change-me":
            raise RuntimeError("正式环境必须设置 TRIBE_TOKEN_PEPPER")
        s.enable_mock_provider = False
        s.enable_mock_payment = False
    return s
