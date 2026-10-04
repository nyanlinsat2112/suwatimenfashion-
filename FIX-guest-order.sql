-- ဒီ SQL ကို Supabase SQL Editor မှာ တစ်ခုတည်း Paste လုပ်ပြီး Run ပါ
-- (ကျန်တဲ့ Schema Error တွေနဲ့ လုံးဝ မသက်ဆိုင်ပါ — ဒါချည်းပဲ Run ရုံနဲ့ ရပါတယ်)

drop policy if exists "Public can create orders" on orders;
create policy "Public can create orders" on orders for insert
  with check (true);

-- Run ပြီးရင် အောက်ကလို "Success" ဆိုတဲ့ Message ပေါ်ရပါမည်
-- ပြီးရင် ဒီ Query ကို ခွဲပြီး Run ကြည့်ပါ (Policy အမှန်တကယ် ဝင်သွားလားဆိုတာ စစ်ရန်)
select policyname, cmd, qual, with_check
from pg_policies
where tablename = 'orders' and cmd = 'INSERT';
