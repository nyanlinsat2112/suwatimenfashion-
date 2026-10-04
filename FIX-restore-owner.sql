-- ချက်ချင်း Run ပါ — Owner Role ကို ပြန်ထည့်ပေးရန်
update admins set role = 'owner' where email = 'nyanlinsat2018@gmail.com';

-- စစ်ဆေးရန်
select email, role from admins where email = 'nyanlinsat2018@gmail.com';
