-- CREATE Database userService; -- not needed as this is done in the docker-compose file

CREATE TABLE public.users (
    UserID UUID PRIMARY KEY,
    PersonName VARCHAR(50) NOT NULL,
    Email VARCHAR(50) NOT NULL,
    Password VARCHAR(50) NOT NULL,
    Gender VARCHAR(50) NOT NULL,
    CONSTRAINT EmailUnique UNIQUE (Email)
);