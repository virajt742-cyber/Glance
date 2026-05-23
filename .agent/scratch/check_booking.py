from app import create_app, db
from app.models import Booking, User

app = create_app()
with app.app_context():
    booking = db.session.get(Booking, 27)
    if booking:
        print(f"Booking 27: Status={booking.status}, Seeker ID={booking.seeker_id}, Provider ID={booking.provider_id}")
        seeker = db.session.get(User, booking.seeker_id)
        provider = db.session.get(User, booking.provider_id)
        print(f"Seeker: {seeker.email if seeker else 'N/A'}")
        print(f"Provider: {provider.email if provider else 'N/A'}")
    else:
        print("Booking 27 not found")
