create database AirportDB;
go
use AirportDB;
go

create table Cities
(
    CityID int primary key identity(1,1) not null,
    CityName nvarchar(50) not null unique,
    CountryName nvarchar(50) not null,
);
go

create table Planes
(
    PlaneID int primary key identity(1,1) not null,
    PlaneModel nvarchar(50) not null unique,
    PlaneCapacity int not null,
);
go

create table Passengers
(
    PassengerID int primary key identity(1,1) not null,
    PassengerName nvarchar(50) not null,
    PassengerSurnameName nvarchar(50) not null,
    PassportNumber nvarchar(20) not null unique,
    PhoneNumber nvarchar(20) not null,
    BirthDate date not null check(BirthDate < getdate()),
    PassengerAge int not null,
);
go

create table Flights
(
    FlightID int primary key identity(1,1) not null,
    FlightNumber nvarchar(20) not null unique,
    DepartureCityID int not null,
    ArrivalCityID int not null,
    DepartureTime datetime not null,
    ArrivalTime datetime not null,
    FlightDuration int not null check(FlightDuration > 0),
    EconomySeats int not null,
    BusinessSeats int not null,
    PlaneID int not null foreign key references Planes(PlaneID),
    constraint FK_DepartureCity foreign key(DepartureCityID) references Cities(CityID),
    constraint FK_Flights foreign key(ArrivalCityID) references Cities(CityID),
);
go

create table Tickets
(
    TicketID int primary key identity(1,1) not null,
    TicketClass nvarchar(20) not null check(TicketClass in ('Economy', 'Business')),
    TicketPrice money not null,
    PassengerID int not null foreign key references Passengers(PassengerID),
    FlightID int not null foreign key references Flights(FlightID),
);
go

create table CrewMembers
(
    CrewMemberID int primary key identity(1,1) not null,
    CrewMemberName nvarchar(50) not null,
    CrewMemberSurnameName nvarchar(50) not null,
    CrewMemberPosition nvarchar(50) not null,
);
go

create table Crews
(
    CrewID int primary key identity(1,1) not null,
    CrewMemberID int not null foreign key references CrewMembers(CrewMemberID),
    FlightID int not null foreign key references Flights(FlightID),
);
go

create trigger CheckAvailableSeats
on Tickets
for insert
as
begin
    declare @FlightID int, @TicketClass nvarchar(20), @SeatsAvailable int;

    select @FlightID = FlightID, @TicketClass = TicketClass
    from inserted;

    if @TicketClass = 'Economy'
    begin
        select @SeatsAvailable = EconomySeats
        from Flights
        where FlightID = @FlightID;

        if @SeatsAvailable <= 0
        begin
            raiserror('No available economy seats for this flight.', 16, 1);
            rollback transaction;
        end
    end
    else if @TicketClass = 'Business'
    begin
        select @SeatsAvailable = BusinessSeats
        from Flights
        where FlightID = @FlightID;

        if @SeatsAvailable <= 0
        begin
            raiserror('No available business seats for this flight.', 16, 1);
            rollback transaction;
        end
    end
end;
go

create trigger UpdateArrivalTime
on Flights
for update
as
begin
    declare @FlightID int, @DepartureTime datetime, @FlightDuration int, @NewArrivalTime datetime;

    select @FlightID = FlightID, @DepartureTime = DepartureTime, @FlightDuration = FlightDuration
    from inserted;

    set @NewArrivalTime = dateadd(minute, @FlightDuration, @DepartureTime);

    update Flights
    set ArrivalTime = @NewArrivalTime
    where FlightID = @FlightID;
end;
go

create trigger InsertPassengerAge
on Passengers
for insert
as
begin
    declare @PassengerID int, @BirthDate date, @PassengerAge int;

    select @PassengerID = PassengerID, @BirthDate = BirthDate
    from inserted;

    set @PassengerAge = datediff(year, @BirthDate, getdate());

    update Passengers
    set PassengerAge = @PassengerAge
    where PassengerID = @PassengerID;
end;
go

create trigger UpdateAvailableSeatsOnTicketDelete
on Tickets
for delete
as
begin
    declare @FlightID int, @TicketClass nvarchar(20);

    select @FlightID = FlightID, @TicketClass = TicketClass
    from deleted;

    if @TicketClass = 'Economy'
    begin
        update Flights
        set EconomySeats = EconomySeats + 1
        where FlightID = @FlightID;
    end
    else if @TicketClass = 'Business'
    begin
        update Flights
        set BusinessSeats = BusinessSeats + 1
        where FlightID = @FlightID;
    end
end;
go

create trigger CheckTicketPriceOnClassChange
on Tickets
for update
as
begin
    declare @TicketID int, @OldClass nvarchar(20), @NewClass nvarchar(20), @OldPrice money, @NewPrice money;

    select @TicketID = TicketID, @OldClass = TicketClass
    from deleted;

    select @NewClass = TicketClass, @NewPrice = TicketPrice
    from inserted;

    if @OldClass <> @NewClass
    begin
        if @NewClass = 'Business'
        begin
            set @NewPrice = 1000;
        end
        else
        begin
            set @NewPrice = 500;
        end

        update Tickets
        set TicketPrice = @NewPrice
        where TicketID = @TicketID;
    end
end;
go

insert into Cities(CityName, CountryName) values
('Kyiv', 'Ukraine'),
('Lviv', 'Ukraine'),
('Minsk', 'Belarus'),
('Warsaw', 'Poland'),
('Paris', 'France'),
('New York', 'USA');
go

insert into Planes(PlaneModel, PlaneCapacity) values
('Boeing 737', 150),
('Airbus A320', 180),
('Boeing 777', 300),
('Airbus A380', 500);
go

insert into Passengers(PassengerName, PassengerSurnameName, PassportNumber, PhoneNumber, BirthDate, PassengerAge) values
('Ivan', 'Ivanov', 'UA1234567', '380501234567', '1985-06-15', 36),
('Anna', 'Petrova', 'UA2345678', '380501234568', '1990-08-20', 31),
('John', 'Doe', 'US1234567', '1234567890', '1982-12-30', 39),
('Maria', 'Smith', 'GB2345678', '0987654321', '1995-03-12', 26),
('Alex', 'Brown', 'CA3456789', '2233445566', '1987-02-22', 34);
go

insert into Flights(FlightNumber, DepartureCityID, ArrivalCityID, DepartureTime, ArrivalTime, FlightDuration, EconomySeats, BusinessSeats, PlaneID) values
('PS101', 1, 2, '2025-03-15 10:00', '2025-03-15 12:30', 150, 100, 20, 1),
('PS102', 3, 4, '2025-03-16 14:00', '2025-03-16 16:30', 120, 120, 30, 2),
('PS103', 2, 5, '2025-03-17 08:30', '2025-03-17 11:00', 150, 90, 15, 3),
('PS104', 4, 6, '2025-03-18 09:00', '2025-03-18 11:30', 180, 130, 40, 4);
go

insert into Tickets(TicketClass, TicketPrice, PassengerID, FlightID) values
('Economy', 300, 1, 1),
('Business', 600, 2, 1),
('Economy', 350, 3, 2),
('Business', 700, 4, 2),
('Economy', 400, 5, 3),
('Business', 800, 1, 4);
go

insert into CrewMembers(CrewMemberName, CrewMemberSurnameName, CrewMemberPosition) values
('Olga', 'Kovalenko', 'Pilot'),
('Serhiy', 'Petrov', 'Co-Pilot'),
('Maria', 'Lysova', 'Flight Attendant'),
('John', 'Smith', 'Flight Attendant'),
('Igor', 'Melnyk', 'Cabin Crew');
go

insert into Crews(CrewMemberID, FlightID) values
(1, 1),
(2, 1),
(3, 2),
(4, 2),
(5, 3),
(1, 4),
(2, 4);
go

select * from Cities;
select * from Planes;
select * from Passengers;
select * from Flights;
select * from Tickets;
select * from CrewMembers;
select * from Crews;
go

select FlightNumber, CityName as ArrivalCity, DepartureTime, ArrivalTime from Flights
join Cities on Flights.ArrivalCityID = Cities.CityID
where CityName = 'Paris' and cast(DepartureTime as date) = '2025-03-17';
go

select FlightNumber, DepartureTime, ArrivalTime, FlightDuration from Flights
where FlightDuration = (select max(FlightDuration) from Flights);
go

select FlightNumber, FlightDuration from Flights
where FlightDuration > 120;
go

select CityName as ArrivalCity, count(FlightID) as FlightsCount from Flights
join Cities on Flights.ArrivalCityID = Cities.CityID
group by CityName;
go

select CityName, count(ArrivalCityID) as NumberOfFlights from Flights
join Cities on Flights.ArrivalCityID = Cities.CityID
where ArrivalCityID = (select max(ArrivalCityID) from Flights)
group by CityName;
go

select CityName as ArrivalCity, count(FlightID) as FlightsCount,
(select count(FlightID) from Flights where month(DepartureTime) = 3 and year(DepartureTime) = 2025) as TotalFlights
from Flights
join Cities on Flights.ArrivalCityID = Cities.CityID
where month(Flights.DepartureTime) = 3 and year(Flights.DepartureTime) = 2025
group by CityName;
go

select FlightNumber, DepartureTime, ArrivalTime, BusinessSeats from Flights
where cast(DepartureTime as date) = '2025-03-15' and BusinessSeats > 0;
go

select FlightNumber, count(TicketID) as TicketsSold, sum(TicketPrice) as TotalAmount from Flights
join Tickets on Flights.FlightID = Tickets.FlightID
where cast(DepartureTime as date) = '2025-03-15'
group by FlightNumber;
go

select FlightNumber, count(TicketID) as TicketsSold from Flights
left join Tickets T on Flights.FlightID = T.FlightID
where cast(DepartureTime as date) = '2025-03-15'
group by FlightNumber;
go

select FlightNumber, CityName as ArrivalCity from Flights
join Cities C on Flights.ArrivalCityID = C.CityID
go


use master;
go
drop database AirportDB;