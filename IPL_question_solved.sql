-- Question 1: Create the database schema

-- Solution
-- creating venue table
create table if not exists venue(
	venue_id int,	
	venue_name varchar(50) not null,
	city_name varchar(50) not null,
	country_name varchar(50) not null,
	constraint pk_venue_venue_id primary key (venue_id)
);
-- getting values from the corresponding excel table
copy venue
from 'D:\Downloads\A Portfolio Projects\SQL Projects\IPL Analysis\Dataset CSV\venue.csv'
delimiter ','
csv header;

select * from venue;

-- creating team table
create table if not exists team(
	team_id int,
	team_name varchar(50) not null,
	constraint pk_team_team_id primary key(team_id)
);

copy team
from 'D:\Downloads\A Portfolio Projects\SQL Projects\IPL Analysis\Dataset CSV\team.csv'
delimiter ','
csv header;

select * from team;

create table if not exists player(
	player_id int,
	player_name varchar(50) not null,
	dob	date not null,
	batting_hand varchar(50) not null,
	bowling_skill varchar(50) not null,
	country_name varchar(50) not null,
	constraint pk_player_player_id primary key(player_id)
);

copy player
from 'D:\Downloads\A Portfolio Projects\SQL Projects\IPL Analysis\Dataset CSV\player.csv'
delimiter ','
csv header;

select * from player;

create table if not exists match(
	match_id int primary key,
	season_year int not null,
	team1 int not null references team(team_id),
	team2 int not null references team(team_id),
	venue_id int not null references venue(venue_id),
	toss_winner int not null references team(team_id),
	match_winner int not null references team(team_id),
	toss_name varchar(50) not null check(toss_name in ('field', 'bat')),
	win_type varchar(50) not null check(win_type in ('wickets', 'runs', 'NULL')),	
	man_of_match int not null references player(player_id),
	win_margin int not null
)

copy match
from 'D:\Downloads\A Portfolio Projects\SQL Projects\IPL Analysis\Dataset CSV\match.csv'
delimiter ','
csv header;

select * from match;

create table if not exists player_match(
	playermatch_key bigint primary key,
	match_id int not null references match(match_id),
	player_id int not null references player(player_id),
	role_desc varchar(50) not null check(role_desc in ('Player', 'Keeper', 'CaptainKeeper', 'Captain')),
	team_id int not null references team(team_id)
);

copy player_match
from 'D:\Downloads\A Portfolio Projects\SQL Projects\IPL Analysis\Dataset CSV\player_match.csv'
delimiter ','
csv header;

select * from player_match;

create table if not exists ball_by_ball(
	match_id int not null references match(match_id),
	innings_no int not null check(innings_no<3 and innings_no>0),
	over_id int not null,
	ball_id int not null,
	runs_scored int not null check(runs_scored<=6 and runs_scored>=0),
	extra_runs int not null,
	out_type varchar(50) not null check(out_type in ('caught', 'caught and bowled', 'bowled', 'stumped', 'retired hurt', 'keeper catch', 'lbw', 'run out', 'hit wicket', 'NULL')),
	striker int not null references player(player_id),
	non_striker int not null references player(player_id),
	bowler int not null references player(player_id),
	constraint pk_ball_by_ball_id primary key(match_id, innings_no, over_id, ball_id)
)

copy ball_by_ball 
from 'D:\Downloads\A Portfolio Projects\SQL Projects\IPL Analysis\Dataset CSV\ball_by_ball.csv'
delimiter ','
csv header;

select * from ball_by_ball;







-- //////////////////////////////////////////////////////////////////////////////////////////////////////



-- Question 2:
-- Find, for each match venue, the average number of runs scored per match (total of both teams) 
-- in the stadium? You can get the runs scored from the ball_by_ball table. 
-- Output (venue_name, total run, no of matches  avg_runs) ,
-- in descending order of average runs per match.
-- Note : Calculate avg_run upto 3 decimal places.

-- Solution 2:
-- Step 1: calculate the no of matches on each venue
with no_of_match_per_venue as
	(
		select v.venue_id, v.venue_name, count(match_id) as no_of_matches from match m
		join venue v
		on v.venue_id=m.venue_id
		group by v.venue_id, v.venue_name
	),
-- Step 2: calculate the total runs on each venue
	total_run_per_venue as
	(
		select v.venue_id, sum(b.runs_scored+b.extra_runs) as total_run from ball_by_ball b
		join match m
		on m.match_id = b.match_id
		join venue v
		on v.venue_id = m.venue_id
		group by v.venue_id
	)
-- Finally use above two temporary tables to calculate the avg run scored per match on each venue 
select  npv.venue_name, tpv.total_run, npv.no_of_matches, round(tpv.total_run/npv.no_of_matches::numeric,3) as avg_run
from no_of_match_per_venue npv
join total_run_per_venue tpv
on npv.venue_id = tpv.venue_id
order by avg_run desc;




-- Question 3:
-- Find players who faced the maximum number of balls per match on average; 
-- a batsman faced a ball if there is an entry in ball_by_ball with that player as the striker.
-- Limit your answer to the top 10 
-- Output (player_id, player_name, average count of balls faced per match)

-- Solution 3:
-- Step 1: count the number of matches played by a player from player_match table
with num_of_match_by_player as
	(
		select player_id, count(match_id) as no_of_match from player_match
		group by player_id
	),
-- Step 2: calculate the total ball played by a player as a striker
	total_ball_played_by_player as
	(
	select striker, count(ball_id) as total_ball_played from ball_by_ball
	group by striker 
	)
-- Finally calculate the top 10 maximum number of balls 
-- played by a player per match on average 
-- using rank function in case of ties we may get more than 10 row
select player_id, player_name, avg_ball_played from
(
select *,
rank() over(order by avg_ball_played desc) from -- use rank function to rank them to inlcude ties
	(
	-- calculate avg
	select p.player_id, p.player_name, (tp.total_ball_played/mp.no_of_match) as avg_ball_played
	from num_of_match_by_player mp, total_ball_played_by_player tp, player p
	where mp.player_id = tp.striker
	and
	p.player_id = mp.player_id
	)
)
where rank<=10; -- get the top 10 


-- Question 4:
-- Find players who are the most frequent six hitters? that is, 
-- players who hit a 6 in the highest fraction of balls that they face. 
-- Output the player id, player name, the number of times the player has got 6 runs in a ball, 
-- the number of balls faced, and the fraction of 6s. 
-- Output (player_id, player_name, numsixes, numballs, frac)
-- (Note 1: The striker attribute in the ball_by_ball relation is the player who scored the runs.)
-- (Note 2: Int divided by int gives an int, so make sure to multiply by 1.0 before division.)

-- Solution 4:
-- calculate no of balls played by each player over the sessions
with ball_by_player as(
	select striker, count(ball_id) as ball_played from ball_by_ball
	group by striker
),
-- calculate no of six's by each player
six_by_player as(
	select striker, count(ball_id) as no_of_six from ball_by_ball
	where runs_scored = 6
	group by striker
)
-- finally get the fraction
select p.player_id, p.player_name, bp.ball_played, sp.no_of_six, 
round((sp.no_of_six::numeric/bp.ball_played),2) as fraction
from ball_by_player as bp, six_by_player as sp, player as p
where bp.striker = sp.striker and bp.striker = p.player_id
order by fraction desc;


-- Question 5:
-- Find top 3 batsmen and top 3 bowlers player_ids 
-- who got highest no of runs and highest no of wickets respectively in each season?
-- Output (season_year, batsman, runs, bowler, wickets). 
-- Here batsman & bowler are player_ids of the players. 
-- Incase of ties output the player with lesser player_id first. 
-- Order by season_year (earlier year comes first) and 
-- rank(batsman and bowler with more no of runs and wickets in a particular season comes first). 
-- There will be (no_of_seasons*3) rows.

-- Solution 5:
-- at first Find top 3 batsmen who got
-- highest no of wickets respectively in each season
with top_batsman as
	(
	select *,
	rank() over(partition by season_year order by run desc, striker) from
		(
		select m.season_year, b.striker, p.player_name, sum(runs_scored) as run
		from ball_by_ball as b, match as m, player as p
		where b.match_id = m.match_id and p.player_id = b.striker
		group by m.season_year, b.striker, p.player_name
		)
	),
-- Secondly, Find top 3 bowler who got highest
-- no of wickets respectively in each season?
top_bowlers as(
	select *,
	rank() over(partition by season_year order by wicket desc, bowler) from
		(
		select m.season_year, b.bowler, p.player_name, count(out_type) as wicket
		from ball_by_ball as b, match as m, player as p
		where b.match_id = m.match_id and p.player_id = b.bowler
		and b.out_type not in ('run out', 'retired hurt')
		group by m.season_year, b.bowler, p.player_name
		)
	)
-- join the above two to get the final result
select tbt.season_year, tbt.striker, tbt.player_name, tbt.run, tbo.bowler, tbo.player_name, tbo.wicket
from top_batsman as tbt, top_bowlers as tbo
where tbt.rank=tbo.rank and tbt.rank<=3 and tbo.rank<=3 and tbt.season_year = tbo.season_year
order by season_year;



-- Question 6: 
-- Find the ids of players who got the highest no of partnership runs for each match?
-- There can be multiple rows for a single match. 
-- Output (match_id, player1, runs1, player2, runs2), 
-- in descending order of partnershiprun (incase of ties compare match_id in ascending order). 
-- run1 > run2 in every row
-- runs1=runs2 then player1_id > player2_id. Note: extra_runs shouldn't be counted

-- Solution 6:
with partnership as
(
	select match_id, striker, non_striker, p_id, p_run from
	(
		select *,
		sum(runs_scored) over(partition by match_id, p_id order by match_id) as p_run,
		row_number() over(partition by match_id, p_id order by match_id) as row_num
		from(
			select b.match_id, b.runs_scored, b.striker, b.non_striker, 
			case when striker<non_striker then concat(non_striker,' ',striker)
			else concat(striker, ' ', non_striker)
			end as p_id
			from ball_by_ball as b
		)
	) where row_num=1
	order by p_run desc, match_id asc	
),
striker_run_contributed as 
	(
	select b.match_id, b.striker, b.non_striker, sum(b.runs_scored) as striker_run 
	from ball_by_ball as b
	group by b.match_id, b.striker, b.non_striker
		),
final_table as 
(
	select p.match_id, p.striker, p.non_striker, sr.striker_run, (p.p_run-sr.striker_run) as non_striker_run,
	p.p_run
	from partnership as p, striker_run_contributed as sr
	where p.match_id = sr.match_id and p.striker = sr.striker and p.non_striker = sr.non_striker
	and p.p_run = (select max(p_run) from partnership as pt where pt.match_id = p.match_id)
	order by p.p_run desc, p.match_id asc
		)
select match_id, 
case when (striker_run = non_striker_run and striker>non_striker) then striker
	 when striker_run>non_striker_run then striker 
	 else non_striker end as player_1,
case when (striker_run>non_striker_run) then striker_run
	 else non_striker_run end as run1,
case when (striker_run = non_striker_run and striker>non_striker) then non_striker
	 when striker_run>non_striker_run then non_striker 
	 else striker end as player_2,
case when (striker_run>non_striker_run) then non_striker_run
	 else striker_run end as run2,
p_run as total_partnership
from final_table;	
	
	

-- Question 7:
-- For all the matches with win type as wickets, find the over ids in which the 
-- runs scored are less than 6 runs? 
-- Output (match_id, innings_no, over_id). Note : Runs scored in an over also include the extra_runs.

-- Solution 7:

select b.match_id, b.innings_no, b.over_id
from ball_by_ball as b
join match as m on m.match_id = b.match_id where win_type = 'wickets'
group by b.match_id, b.innings_no, b.over_id
having sum(b.runs_scored)+sum(extra_runs)<6	;




-- Question 8:
-- List top 5 batsmen by number of sixes hit in the season 2013?. Output (player_name).

-- Solution 8:
select p.player_name from ball_by_ball as b, match as m, player as p
where (b.match_id = m.match_id and b.striker = p.player_id) and (m.season_year = 2013 and b.runs_scored = 6)
group by b.striker, p.player_name order by count(runs_scored) desc limit 5 ;
	
	
	
	
-- Q 9: List 5 bowlers by lowest strike rate(average number of balls bowled per wicket taken) 
-- in the season 2013?  Break ties alphabetically. Output (player_name).

-- Solution 9:
with wicket as 
(
	select b.bowler, p.player_name, count(out_type) as no_of_wicket from ball_by_ball as b, player as p, match as m
	where (b.bowler = p.player_id and b.match_id = m.match_id) 
	and (b.out_type not in ('NULL', 'retired hurt', 'run out') and m.season_year = 2013)
	group by b.bowler, p.player_name
),
balls as 
(
	select b.bowler, p.player_name, count(ball_id) as no_of_ball from ball_by_ball as b, player as p, match as m
	where (b.bowler = p.player_id and b.match_id = m.match_id) and m.season_year = 2013
	group by b.bowler, p.player_name 

)
select b.player_name, b.no_of_ball/w.no_of_wicket as ratio from wicket as w, balls as b
where w.bowler = b.bowler
order by ratio desc , b.player_name limit 5;



-- Question 10:
-- For each country(with at least one player bowled out) 
-- find out the number of its players who were bowled out in any match?
-- Output (country_name, count). Here the country is the home country of the player.

-- Solution:
select p.country_name, count(striker) no_of_bowled_out from ball_by_ball as b, player as p
where p.player_id = b.striker and b.out_type = 'bowled'
group by p.country_name having count(striker)>0 order by no_of_bowled_out desc;



-- Question 11:
-- List the names of right- handed players who have scored at least a century 
-- in any match played in 'Pune' ? Order the output alphabetically on player_name. Output (player_name).

-- Solution 11:
select p.player_name, sum(runs_scored) as run  
from ball_by_ball as b, match as m, venue as v, player as p
where (b.match_id = m.match_id and m.venue_id = v.venue_id 
	   and p.player_id = b.striker and v.city_name = 'Pune' and p.batting_hand = 'Right-hand bat')
group by b.striker, p.player_name having sum(runs_scored)>=100 order by run desc, p.player_name;




