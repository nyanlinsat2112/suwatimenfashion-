-- ၁) သင့် admins table ထဲက Data အားလုံးကို ကြည့်ပါ
select * from admins;

-- ၂) role NULL ဖြစ်နေရင် (သို့) "owner" မဟုတ်ရင် — အောက်က UPDATE ကို run ပါ
-- (user_id နေရာမှာ အထက်က select ရလဒ်ထဲက သင့် UID အတိအကျ ထည့်ပါ)
-- update admins set role = 'owner' where user_id = 'ဒီနေရာမှာ-သင့်-UID';

-- ၃) is_owner() function အလုပ်လုပ်မလုပ် စစ်ဆေးရန် (Logged-in Admin အနေနှင့် Run ရပါမည်)
-- select is_owner();
