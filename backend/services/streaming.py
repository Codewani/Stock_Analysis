import uuid
from collections.abc import Iterable

from sqlalchemy.orm import Session

from backend.models.auth.user import User
from backend.services.concerned_users import get_concerned_user_ids


def get_users_by_symbols(symbols: Iterable[str], db: Session) -> list[User]:
	user_ids = get_concerned_user_ids(symbols, db)
	if not user_ids:
		return []

	return db.query(User).filter(User.user_id.in_([uuid.UUID(user_id) for user_id in user_ids])).all()
