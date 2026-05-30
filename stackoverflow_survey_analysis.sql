-- ============================================================
-- PROJECT  : Stack Overflow Developer Survey 2025 Analysis
-- AUTHOR   : Sparsh Kapoor
-- DATABASE : Microsoft SQL Server
-- DATASET  : Stack Overflow Developer Survey 2025
--            Source: https://survey.stackoverflow.co/
-- ============================================================
-- BUSINESS QUESTIONS:
--   Q1: Which programming languages are worth learning in 2025?
--   Q2: At what experience level does salary stop growing?
--   Q3: Which role + work arrangement has highest job satisfaction?
--   Q4: Which roles have the best salary growth with experience?
--   Q5: Does a university degree still matter in tech in 2025?
-- ============================================================


-- ============================================================
-- STEP 0: DATABASE SETUP
-- ============================================================

create database stackoverflow_survey;

use stackoverflow_survey;

-- quick peek at raw data
select top 5 * from survey_results;

-- check all column names in the table
select column_name 
from information_schema.columns
where table_name = 'survey_results'
order by ordinal_position;


-- ============================================================
-- STEP 1: EXPLORATORY DATA ANALYSIS (EDA)
-- Goal: Understand the data before cleaning anything
-- Rule: For every column we check 3 things:
--       1. How many NULLs?
--       2. How many distinct values?
--       3. What are those values?
-- ============================================================

-- total rows in dataset
select count(*) as total_rows 
from survey_results;
-- result: 49,191 rows


-- ------------------------------------------------------------
-- COLUMN 1: convertedcompyearly (salary)
-- Type: Numeric — check NULLs + min/max
-- ------------------------------------------------------------

-- check 1: count nulls
select count(*) as null_salary
from survey_results
where convertedcompyearly is null;
-- result: 25,244 nulls (51%)

-- check 2: count distinct values
select count(distinct convertedcompyearly) as distinct_salary
from survey_results;
-- result: 6,237 distinct salary values

-- check 3: min and max values
select 
    min(convertedcompyearly) as min_salary,
    max(convertedcompyearly) as max_salary
from survey_results;
-- result: min = 1 (unrealistic), max = 50,000,000 (unrealistic)

-- findings:
-- finding 1: 51% of respondents skipped the salary question
-- finding 2: min salary of $1 is clearly incorrect data
-- finding 3: max salary of $50,000,000 is unrealistic
-- solution : filter salary between $10,000 and $400,000


-- ------------------------------------------------------------
-- COLUMN 2: workexp (years of work experience)
-- Type: Text/Numeric — check NULLs + distinct values
-- ------------------------------------------------------------

-- check 1: count nulls
select count(*) as null_workexp
from survey_results
where workexp is null;
-- result: 6,298 nulls (13%)

-- check 2: count distinct values
select count(distinct workexp) as distinct_workexp
from survey_results;
-- result: 72 distinct values

-- check 3: see what those values are
select distinct workexp
from survey_results
order by workexp;
-- result: values range from 1 to 100

-- findings:
-- finding 1: 13% of respondents skipped work experience
-- finding 2: values above 50 are unrealistic (82, 88, 99, 100 etc)
-- solution : filter workexp between 1 and 50 years


-- ------------------------------------------------------------
-- COLUMN 3: remotework (work arrangement)
-- Type: Text/Category — check NULLs + distinct values
-- ------------------------------------------------------------

-- check 1: count nulls
select count(*) as null_remotework
from survey_results
where remotework is null;
-- result: 15,411 nulls (31%)

-- check 2: count distinct values
select count(distinct remotework) as distinct_remotework
from survey_results;
-- result: 5 distinct categories

-- check 3: see what those values are
select distinct remotework
from survey_results
order by remotework;
-- result: 5 categories including 2 hybrid variations

-- findings:
-- finding 1: 31% of respondents skipped this question
-- finding 2: 5 clean categories exist with no typos
-- finding 3: 2 hybrid categories can be simplified into 1
-- solution : filter nulls, simplify both hybrid categories into 'hybrid'


-- ------------------------------------------------------------
-- COLUMN 4: jobsat (job satisfaction score)
-- Type: Numeric Scale — check NULLs + distinct values
-- ------------------------------------------------------------

-- check 1: count nulls
select count(*) as null_jobsat
from survey_results
where jobsat is null;
-- result: 22,521 nulls (46%)

-- check 2: count distinct values
select count(distinct jobsat) as distinct_jobsat
from survey_results;
-- result: 11 distinct values (0 to 10)

-- check 3: see what those values are
select distinct jobsat
from survey_results
order by jobsat;
-- result: clean scale from 0 to 10

-- findings:
-- finding 1: 46% of respondents skipped job satisfaction question
-- finding 2: clean scale of 0-10 with no unrealistic values
-- finding 3: 0 = very unsatisfied, 10 = very satisfied
-- solution : filter nulls only, no other cleaning needed


-- ------------------------------------------------------------
-- COLUMN 5: devtype (developer role)
-- Type: Text/Category — check NULLs + distinct values
-- ------------------------------------------------------------

-- check 1: count nulls
select count(*) as null_devtype
from survey_results
where devtype is null;
-- result: 5,511 nulls (11%)

-- check 2: count distinct values
select count(distinct devtype) as distinct_devtype
from survey_results;
-- result: 32 distinct developer roles

-- check 3: see distinct values
select distinct devtype
from survey_results
order by devtype;
-- result: 32 roles including some irrelevant ones

-- findings:
-- finding 1: only 11% nulls - relatively clean column
-- finding 2: 32 distinct roles, mostly valid
-- finding 3: 'other', 'retired', 'student' are not relevant for salary analysis
-- solution : filter nulls and exclude irrelevant roles


-- ------------------------------------------------------------
-- COLUMN 6: edlevel (education level)
-- Type: Text/Category — check NULLs + distinct values
-- ------------------------------------------------------------

-- check 1: count nulls
select count(*) as null_edlevel
from survey_results
where edlevel is null;
-- result: 1,042 nulls (2%) - cleanest column!

-- check 2: count distinct values
select count(distinct edlevel) as distinct_edlevel
from survey_results;
-- result: 8 distinct education levels

-- check 3: see distinct values
select distinct edlevel
from survey_results
order by edlevel;
-- result: 8 levels including some irrelevant ones

-- findings:
-- finding 1: only 2% nulls - cleanest column in our dataset
-- finding 2: 8 distinct values, well structured
-- finding 3: 'primary school' and 'secondary school' not relevant for tech salary
-- solution : keep only degree level and above, exclude primary/secondary/other


-- ============================================================
-- STEP 2: DATA CLEANING
-- Goal: Create a clean view that fixes all issues found in EDA
-- Note: Original table is NEVER modified — view is a virtual lens
-- Result: 13,571 clean rows ready for analysis
-- ============================================================

create view clean_survey as
select
    -- convert experience from text to number
    cast(workexp as float) as experience,

    -- convert salary from text to number
    cast(convertedcompyearly as float) as salary,

    -- simplify 5 remote work categories into 3 clean ones
    case
        when remotework = 'Remote'          then 'Remote'
        when remotework like '%Hybrid%'     then 'Hybrid'
        when remotework = 'In-person'       then 'In-person'
        else null  -- 'your choice (flexible)' becomes null and gets filtered
    end as remote_work,

    -- convert job satisfaction from text to integer
    cast(jobsat as int) as job_satisfaction,

    -- developer role (kept as is)
    devtype,

    -- education level renamed for clarity
    edlevel as education,

    -- languages worked with (kept as is, split at query level)
    languagehaveworkedwith as languages

from survey_results

-- filter 1: keep only realistic salary range
where cast(convertedcompyearly as float) between 10000 and 400000

-- filter 2: keep only realistic experience range
and cast(workexp as float) between 1 and 50

-- filter 3: remove null rows for all key columns
and remotework              is not null
and jobsat                  is not null
and devtype                 is not null
and edlevel                 is not null
and languagehaveworkedwith  is not null

-- filter 4: exclude irrelevant developer roles
and devtype not like '%Other%'
and devtype not like '%Retired%'
and devtype not like '%Student%'

-- filter 5: exclude irrelevant education levels
and edlevel not in (
    'Primary/elementary school',
    'Secondary school (e.g. American high school, German Realschule or Gymnasium, etc.)',
    'Other (please specify):'
);

-- verify clean row count
select count(*) as clean_rows 
from clean_survey;
-- result: 13,571 clean rows
-- note: reduced from 49,191 due to nulls, outliers and irrelevant categories


-- ============================================================
-- STEP 3: ANALYSIS — BUSINESS QUESTIONS
-- ============================================================


-- ============================================================
-- Q1: WHICH PROGRAMMING LANGUAGES ARE WORTH LEARNING IN 2025?
-- Approach: Find languages that are BOTH high paying AND widely used
-- Columns : languages, salary
-- Concepts: STRING_SPLIT, CROSS APPLY, TRIM, HAVING
-- ============================================================

-- note: the 'languages' column stores multiple values like:
--       'Python;JavaScript;SQL'
--       we use string_split + cross apply to split into individual rows
--       while keeping the salary connection intact

-- sub query 1: most used languages (demand side)
select top 15
    trim(value) as language,
    count(*) as total_users
from clean_survey
cross apply string_split(languages, ';')
where trim(value) != ''          -- remove empty strings after splitting
group by trim(value)
order by total_users desc;

-- sub query 2: highest paying languages (salary side)
select top 15
    trim(value) as language,
    round(avg(salary), 0) as avg_salary
from clean_survey
cross apply string_split(languages, ';')
where trim(value) != ''
group by trim(value)
having count(*) > 1000           -- only languages used by 1000+ people
order by avg_salary desc;        -- removes niche languages with misleading averages

-- q1 final: combining both — best languages showing demand + salary together
select top 15
    trim(value)             as language,
    count(*)                as total_users,
    round(avg(salary), 0)   as avg_salary
from clean_survey
cross apply string_split(languages, ';')
where trim(value) != ''
group by trim(value)
having count(*) > 1000
order by avg_salary desc;

-- ------------------------------------------------
-- q1 findings:
-- finding 1: go pays the most at $115,805 avg salary
-- finding 2: rust second highest at $111,748
-- finding 3: python is the best overall balance —
--            4th in salary ($103,461) and 4th in usage (7,521 users)
-- finding 4: javascript is most popular (9,273 users) but ranks 13th in salary
-- finding 5: html/css has 2nd most users but lowest salary ($95,556)
-- insight  : python offers the best salary-to-demand ratio in 2025
-- ================================================


-- ============================================================
-- Q2: AT WHAT EXPERIENCE LEVEL DOES SALARY STOP GROWING?
-- Approach: Group experience into brackets and compare avg salary
-- Columns : experience, salary
-- Concepts: CASE WHEN in SELECT and GROUP BY, ORDER BY with numbers
-- ============================================================

-- note: grouping by individual years gives 50 rows and is hard to read
--       instead we create 6 meaningful experience brackets
--       numbers (1., 2., 3.) are added to force correct sort order
--       since order by sorts text alphabetically by default

select
    case
        when experience between 0  and 2  then '1. junior (0-2 years)'
        when experience between 3  and 5  then '2. early mid (3-5 years)'
        when experience between 6  and 10 then '3. mid level (6-10 years)'
        when experience between 11 and 15 then '4. senior (11-15 years)'
        when experience between 16 and 20 then '5. expert (16-20 years)'
        else                                   '6. veteran (21+ years)'
    end                         as experience_level,
    count(*)                    as total_people,
    round(avg(salary), 0)       as avg_salary
from clean_survey
group by
    -- group by must repeat case when because group by runs before select
    case
        when experience between 0  and 2  then '1. junior (0-2 years)'
        when experience between 3  and 5  then '2. early mid (3-5 years)'
        when experience between 6  and 10 then '3. mid level (6-10 years)'
        when experience between 11 and 15 then '4. senior (11-15 years)'
        when experience between 16 and 20 then '5. expert (16-20 years)'
        else                                   '6. veteran (21+ years)'
    end
order by experience_level;

-- ------------------------------------------------
-- q2 findings:
-- finding 1: junior avg salary is $52,957 — lowest bracket
-- finding 2: biggest salary jump is between 3-10 years (+$30,349, +49%)
-- finding 3: salary never fully stops growing even at veteran level
-- finding 4: growth rate drops sharply from 49% to 7% after senior level
-- insight  : salary growth rate plateaus at 11+ years, not salary itself
-- ================================================


-- ============================================================
-- Q3: WHICH ROLE + WORK ARRANGEMENT HAS HIGHEST JOB SATISFACTION?
-- Approach: Compare avg job satisfaction by work arrangement and role combo
-- Columns : remote_work, job_satisfaction, devtype
-- Concepts: GROUP BY multiple columns, HAVING with two-column grouping
-- ============================================================

-- part 1: overall satisfaction by work arrangement
select
    remote_work,
    count(*)                            as total_people,
    round(avg(job_satisfaction), 1)     as avg_satisfaction
from clean_survey
group by remote_work
order by avg_satisfaction desc;

-- part 2: satisfaction by role + work arrangement combination
-- note: using having count(*) > 50 because grouping by 2 columns
--       creates ~96 combinations (32 roles x 3 arrangements)
--       so fewer people per group — threshold lowered from 500 to 50
select top 15
    devtype                             as developer_role,
    remote_work                         as work_arrangement,
    count(*)                            as total_people,
    round(avg(job_satisfaction), 1)     as avg_satisfaction
from clean_survey
where remote_work is not null           -- filter nulls created by case when in view
group by devtype, remote_work
having count(*) > 50                    -- remove combos with too few people
order by avg_satisfaction desc;

-- ------------------------------------------------
-- q3 findings:
-- finding 1: senior executive + remote scores highest at 8/10
-- finding 2: hybrid work dominates the top 15 results
-- finding 3: in-person appears only once in top 15
-- finding 4: most roles consistently score 7/10 regardless of arrangement
-- insight  : flexibility matters more than location for job satisfaction
-- ================================================


-- ============================================================
-- Q4: WHICH ROLES HAVE THE BEST SALARY GROWTH WITH EXPERIENCE?
-- Approach: Compare junior vs senior salary per role using CTEs
-- Columns : devtype, experience, salary
-- Concepts: CTEs (WITH clause), INNER JOIN, growth % formula, CAST
-- ============================================================

-- note: we use 2 CTEs to calculate junior and senior salaries separately
--       then join them to calculate growth percentage
--       junior  = experience <= 5 years
--       senior  = experience > 10 years
--       cast to float needed because round() returns integer
--       and integer division gives wrong results (70000/65000 = 1, not 1.07)

-- step 1: cte for junior salary per role (0-5 years experience)
with junior as (
    select
        devtype,
        round(avg(salary), 0) as junior_salary
    from clean_survey
    where experience <= 5
    group by devtype
),

-- step 2: cte for senior salary per role (10+ years experience)
senior as (
    select
        devtype,
        round(avg(salary), 0) as senior_salary
    from clean_survey
    where experience > 10
    group by devtype
)

-- step 3: inner join both ctes and calculate salary growth percentage
-- inner join keeps only roles that exist in both junior and senior data
select top 15
    j.devtype                   as developer_role,
    j.junior_salary,
    s.senior_salary,
    round(
        ((cast(s.senior_salary as float) - cast(j.junior_salary as float))
        / cast(j.junior_salary as float)) * 100
    , 1)                        as growth_percentage
from junior j
join senior s on j.devtype = s.devtype
order by growth_percentage desc;

-- ------------------------------------------------
-- q4 findings:
-- finding 1: senior executive shows 478% growth but junior salary
--            of $27,264 is an outlier — likely career switchers
-- finding 2: mobile developer has best realistic growth at 152.5%
-- finding 3: cloud engineer reaches highest senior salary at $160,076
-- finding 4: ai/ml engineer starts highest ($82,078) but grows slowest (87.4%)
--            suggesting ai skills are already premium at junior level
-- finding 5: financial analyst has highest senior salary among analysts ($198,338)
-- insight  : mobile and cloud offer best long term salary growth trajectories
-- ================================================


-- ============================================================
-- Q5: DOES A UNIVERSITY DEGREE STILL MATTER IN TECH IN 2025?
-- Approach: Compare avg salary across education levels
-- Columns : education, salary
-- Concepts: Simple GROUP BY with ORDER BY — straightforward aggregation
-- ============================================================

select
    education,
    count(*)                as total_people,
    round(avg(salary), 0)   as avg_salary
from clean_survey
group by education
order by avg_salary desc;

-- ------------------------------------------------
-- q5 findings:
-- finding 1: professional degree (phd/md/jd) pays most at $114,039
--            but only 630 respondents — very small group
-- finding 2: bachelor's degree is the sweet spot —
--            most people (6,534) with strong salary ($101,003)
-- finding 3: master's degree pays LESS than bachelor's ($98,615 vs $101,003)
--            extra years of study may not be worth it financially
-- finding 4: no degree earns $92,383 — only 8% less than bachelor's
--            skills matter more than credentials in tech
-- finding 5: associate degree pays the least at $88,211
-- insight  : a bachelor's degree is the sweet spot but self-taught
--            developers are surprisingly competitive in 2025
-- ================================================


-- ============================================================
-- PROJECT SUMMARY
-- ============================================================
-- raw data   : 49,191 respondents from 177 countries
-- clean data : 13,571 respondents after removing nulls and outliers
-- questions  : 5 business questions answered
--
-- key insights:
-- 1. python is the best language to learn in 2025 (demand + salary balance)
-- 2. salary growth rate plateaus after 11 years — not salary itself
-- 3. hybrid work dominates job satisfaction across all roles
-- 4. mobile and cloud roles offer best long term salary growth
-- 5. a degree helps but self-taught developers earn only 8% less
-- ============================================================
