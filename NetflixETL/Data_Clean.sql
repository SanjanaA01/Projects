drop table [NETFLIX_db].[dbo].[netflix_raw]

create table [NETFLIX_db].[dbo].[netflix_raw]
(
      [show_id] [varchar](10) primary key
      ,[type] [varchar](10) NUll
      ,[title] [nvarchar](200) NUll
      ,[director] [varchar](250) NUll
      ,[cast] [varchar](1000) NUll
      ,[country] [varchar](150) NUll
      ,[date_added]  [varchar](20) NUll
      ,[release_year] int NULL
      ,[rating] [varchar](10) NUll
      ,[duration] [varchar](10) NUll
      ,[listed_in] [varchar](100) NUll
      ,[description] [varchar](500) NUll
	  )
	  Go

	  select title, count(*) 
	  from [NETFLIX_db].[dbo].[netflix_raw]
	  group by title
	  having count(*)>1

	  --check where are title duplicates
	    select *
	  from [NETFLIX_db].[dbo].[netflix_raw]
	  where title  IN (
	  select title
	  from [NETFLIX_db].[dbo].[netflix_raw]
	  group by title,type
	  having count(*)>1)
	  order by title

	  --removing duplicates
	  with dup as
	  (
	  select *, row_number() over(partition by title, type order by show_id) as rn
	  from [NETFLIX_db].[dbo].[netflix_raw]
	  )
	  select show_id, type, title,cast(date_added as date) as date_added, release_year
	  ,rating, case when duration is null then rating else duration end as duration,description 
	  -- wherever duration is null, basically the values of rating are equal to duration
	  into netlifix_stg
	  from dup
	  where rn = 1

	  select * from netlifix_stg
	  -- create a separate column for director
	  select show_id, trim(value) as director
	  into netflix_directors
	  from netflix_raw
	  cross apply string_split(director,',')
	  
	    -- create a separate column for country
	  select show_id, trim(value) as country
	  into netflix_country
	  from netflix_raw
	  cross apply string_split(country,',')

	     -- create a separate column for cast
	  select show_id, trim(value) as cast
	  into netflix_cast
	  from netflix_raw
	  cross apply string_split(cast,',')

	   -- create a separate column for listedin
	  select show_id, trim(value) as genre
	  into netflix_genre
	  from netflix_raw
	  cross apply string_split(listed_in,',')

	  select * from netflix_genre

	  --from directors we can assume the corresponding country
	  insert into netflix_country
	  select show_id, nr.country  from netflix_raw nc
	  inner join (  select director, country -- data mapping
	  from netflix_country nc
	  inner join netflix_directors  nd on nc.show_id = nd.show_id
	  group by director, country
	  ) nr on nr.director = nc.director
	  where nc.country is null


	  --n for each director count the no. of movies and tv shows created by in separate columns
	  -- for directors who have created both movies and tv shows

	    select n.director, count(s.type) as TVshow, l.moviecount
	  from netflix_directors n
	  left join netlifix_stg s on n.show_id = s.show_id
	  inner join (select nd.director, count(ns.type) as moviecount
	  from netflix_directors nd
	  left join netlifix_stg ns on nd.show_id = ns.show_id
	  where ns.type = 'movie'
	  group by director) l on l.director = n.director
	  where s.type = 'TV Show' 
	  group by n.director, l.moviecount
	  order by n.director


	  --other simpler way

	  select nd.director,
	  count(distinct case when n.type = 'Movie' then n.show_id end) as no_movie
	  ,count(distinct case when n.type = 'TV Show' then n.show_id end) as no_tvshow
	  from netlifix_stg n
	  inner join netflix_directors nd on n.show_id = nd.show_id
	  group by director
	  having count(distinct n.type) > 1
	
	-- which country has highest number of comedy movies
	select top 1 nc.country, count(distinct ng.show_id) as no_ofmovies
	from netflix_genre ng
	inner join netflix_country nc on ng.show_id = nc.show_id
	inner join netlifix_stg n on ng.show_id = n.show_id
	where ng.genre = 'Comedies' and n.type = 'Movie'
	group by nc.country
	order by no_ofmovies desc
	
-- for each year which director has max number of moves
select * from (
select l.Yearadded,l.director,l.no_ofmovies, row_number() over (partition by l.Yearadded  order by l.no_ofmovies desc, director) as rn --incase of ties the director with alphabetic value coming first
from (
select count(distinct ng.show_id) as no_ofmovies, nd.director,YEAR(ng.date_added) as Yearadded
from netlifix_stg ng
inner join netflix_directors nd on ng.show_id = nd.show_id
where ng.type = 'Movie'
group by nd.director,YEAR(ng.date_added)) l
) g 
where g.rn = 1


-- average duration of movies
--duration is varchar we can't directly calculate average so need to change it to integer

select ng.genre , avg(cast(REPLACE(n.duration,' min','') as int)) as duration_int
from netlifix_stg n
inner join netflix_genre ng on ng.show_id = n.show_id
where n.type= 'Movie' group by ng.genre


--display director names along with number of comedy and horror movies both

  select nd.director
	  ,count(distinct case when n.genre = 'Comedies' then n.show_id end) as no_comedy
	 , count(distinct case when n.genre = 'Horror Movies' then n.show_id end) as no_horrow
	  from netlifix_stg ns
	  inner join  netflix_genre n  on ns.show_id = n.show_id
	  inner join netflix_directors nd on ns.show_id = nd.show_id
	  where ns.type = 'Movie' and n.genre in ('Comedies' ,'Horror Movies')
	  group by nd.director
	  having count(distinct n.genre)>1

	  















