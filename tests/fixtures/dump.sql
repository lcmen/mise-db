drop table if exists mise_db_restore_fixture;

create table mise_db_restore_fixture (
  id integer primary key,
  label text not null
);

insert into mise_db_restore_fixture (id, label) values
  (1, 'alpha'),
  (2, 'bravo'),
  (3, 'charlie');
