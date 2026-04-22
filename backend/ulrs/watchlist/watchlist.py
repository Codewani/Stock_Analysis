from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session
from backend.models.auth.user import UserInDB
from typing import Annotated
from backend.ulrs.utils.db.db_utils import get_db
from backend.ulrs.utils.auth.user import *
from backend.ulrs.utils.watchlist.req_res_models import *
from backend.ulrs.utils.watchlist.helper_functions import get_user_watchlist
from backend.models.watchlist.watchlist import *
from backend.ulrs.utils.caching.watchlist.redis_cache import delete_cached_watchlist

@router.get("/watchlist", response_model=list[WatchlistEntry])
def get_watchlist(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
):
    return get_user_watchlist(current_user.user_id, db)


@router.post("/add_to_watchlist", response_model=WatchlistResponse)
def add_to_watchlist(watchlist_item: WatchlistItem, current_user: Annotated[UserInDB, Depends(get_current_user)], db: Session = Depends(get_db)):
    
    new_watchlist_item = WatchList(
        user_id=current_user.user_id,
        symbol=watchlist_item.symbol
    )


    db.add(new_watchlist_item)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to create item to watchlist")

    db.refresh(new_watchlist_item)
    delete_cached_watchlist(user_id=current_user.user_id)

    return WatchlistResponse(user_id=current_user.user_id, message=f"{watchlist_item.symbol} has successfully been added to your watchlist")

@router.post("/remove_from_watchlist", response_model=WatchlistResponse)
def remove_from_watchlist(watchlist_item: WatchlistItem, current_user: Annotated[UserInDB, Depends(get_current_user)], db: Session = Depends(get_db)):

    item = (
    db.query(WatchList)
    .filter(
        WatchList.user_id == current_user.user_id,
        WatchList.symbol == watchlist_item.symbol,
    )
    .first()
    )

    if not item:
        raise HTTPException(status_code=404, detail="Watchlist item not found")

    db.delete(item)
    db.commit()
    delete_cached_watchlist(user_id=current_user.user_id)

    return WatchlistResponse(user_id=current_user.user_id, message=f"{watchlist_item.symbol} has successfully been removed from your watchlist")
