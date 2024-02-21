-- Part 1
-- 1
CREATE TABLE employees
(
Emp# NUMBER(5,0),
Firstname CHAR(12),
Lastname CHAR(12),
Job_class VARCHAR(4)
);


--2
ALTER TABLE employees
ADD
(
EmpDate DATE DEFAULT SYSDATE,
EndDate DATE
);

--3
ALTER TABLE employees
MODIFY Job_class VARCHAR2(6);

--4
ALTER TABLE employees
DROP COLUMN EndDate;

--5
CREATE TABLE JL_EMPS
AS(SELECT Emp#,firstname,lastname
FROM employees
);

--6
TRUNCATE TABLE jl_emps;

SELECT *
FROM jl_emps;

--7
DROP TABLE jl_emps PURGE;

--8
DROP TABLE employees;

--9
FLASHBACK TABLE employees
TO BEFORE DROP;



-- Part 2
SELECT *
FROM books;

--1
CREATE TABLE category
(
catcode CHAR(3) CONSTRAINT category_catcode_pk PRIMARY KEY,
catdesc VARCHAR(14) NOT NULL
);

INSERT INTO category
VALUES('BUS', 'BUSINESS');
INSERT INTO category
VALUES('CHN', 'CHILDREN');
INSERT INTO category
VALUES('COK', 'COOKING');
INSERT INTO category
VALUES('COM', 'COMPUTER');
INSERT INTO category
VALUES('FAL', 'FAMILY LIFE');
INSERT INTO category
VALUES('FIT', 'FITNESS');
INSERT INTO category
VALUES('SEH', 'SELF HELP');
INSERT INTO category
VALUES('LIT', 'LITERATURE');

SELECT *
FROM category;

--2
ALTER TABLE books
ADD CatCode CHAR(3);

--3
ALTER TABLE books
ADD CONSTRAINT books_catcode_fk FOREIGN KEY (catcode)
    REFERENCES category(catcode);

UPDATE books
SET catcode =
(SELECT catcode
 FROM category
 WHERE category.catdesc = books.category
 );

--4
SELECT *
FROM books;

--5
COMMIT;

--6
ALTER TABLE books
DROP COLUMN category;

--7
CREATE TABLE CATEGORY1
AS (SELECT *
    FROM category);

DROP TABLE category CASCADE CONSTRAINTS;









