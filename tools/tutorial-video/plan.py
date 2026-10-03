import json, subprocess, os, re
T='/private/tmp/claude-501/-Users-raniophir-ChildTime/1dc2083a-3de8-4dc0-b3fd-aa18f2342293/scratchpad/tutorial'
R=T+'/rec/'
LEAD=0.8; TAIL=1.3
lines={}
for l in open(T+'/lines.txt', encoding='utf-8'):
    l=l.rstrip('\n')
    if not l: continue
    i,sub,spk=l.split('|'); lines[i]=(sub,spk)
def dur(path):
    out=subprocess.run([T+'/vtool','probe',path],capture_output=True,text=True).stdout
    return float(re.search(r'dur=([\d.]+)',out).group(1))
# scene: (id, title, clips[(file,kind,from,dur|None)], tail override, fixed D)
P='phone'; I='ipad'
scenes=[
 ('01','פתיחה — מסך ברוכים הבאים',[('s01_welcome',P,0.4,None)],None,None),
 ('02','בחירת תפקיד (המכשיר שלי — הורה)',[('s02_rolepicker',P,0.5,None)],None,None),
 ('03','משפחה חדשה → קוד הורה → יצירת ילד',[('s03a_family',P,0.5,2.0),('s03b_gate',P,0.3,2.4),('s03c_create',P,14.6,None)],None,None),
 ('04','מסך הבית של ההורה',[('s04_parenthome',P,0.5,None)],None,None),
 ('05','חיבור האייפד של הילד (סריקת קוד)',[('s05_childjoin',I,0.5,None)],None,None),
 ('06','בחירת אפליקציות לנעילה',[('s06_applock',I,0.5,None)],None,None),
 ('07','מסך הבית של הילד — עולמות',[('s07b_kidhome_phone',P,1.0,None)],None,None),
 ('08a','שאלה — תשובה נכונה',[('s08_question',I,17.4,None)],None,None),
 ('08b','שאלה — טעות עדינה',[('s08_question',I,3.7,None)],1.5,None),
 ('09','גלגל מזל + קופסת קסם יומית',[('s09a_wheel',I,25.9,5.1),('s09b_chest',I,2.8,None)],None,8.6),
 ('10','פתיחת זמן מסך',[('s07_kidhome',I,0.5,2.8),('s10_opening',I,0.5,None)],None,None),
 ('11','כרטיס הילד — פעולות מהירות',[('s11_child',P,2.0,None)],None,None),
 ('12','כרטיס הילד — דוח והתקדמות',[('s11_child',P,12.6,4.0),('s11_child',P,20.6,None)],1.7,None),
 ('13','מטלות בית (ילד → הורה)',[('s13a_choreskid',I,0.5,3.0),('s13b_choresparent',P,0.5,None)],None,None),
 ('14','הגדרות הילד',[('s11_child',P,70.0,None)],None,None),
 ('15','סיום',[('s01_welcome',P,3.0,None)],0.7,None),
]
def split_chunks(text):
    if len(text)<=48: return [text]
    # split at punctuation nearest middle
    cands=[m.end() for m in re.finditer(r'[,.:?!] ', text)]
    mid=len(text)/2
    k=min(cands,key=lambda c:abs(c-mid))
    return [text[:k].strip(), text[k:].strip()]
def two_lines(t):
    if len(t)<=24: return t
    sp=[m.start() for m in re.finditer(' ', t)]
    mid=len(t)/2
    k=min(sp,key=lambda c:abs(c-mid))
    return t[:k]+'\\n'+t[k+1:]
layout=dict(l.rstrip('\n').split('=',1) for l in open(T+'/subs_layout.txt',encoding='utf-8') if '=' in l)
clips=[]; subs=[]; audio=[]; script=[]
t=0.0; n=0
for sid,title,cl,tail,fixedD in scenes:
    ad=dur(f'{T}/tts/line{sid}.aiff')
    D=fixedD if fixedD else LEAD+ad+(tail if tail else TAIL)
    D=round(D*30)/30
    a0=t+LEAD; a1=a0+ad
    audio.append((f'{T}/tts/line{sid}.aiff',round(a0,3)))
    fixed=sum(c[3] for c in cl if c[3]); rem=D-fixed
    for f,k,fr,d in cl:
        clips.append({'file':R+f+'.mov','kind':k,'from':fr,'dur':round((d if d else rem)*30)/30})
    sub=lines[sid][0]; chunks=[c.strip() for c in layout[sid].split('||')]
    tot=sum(len(c) for c in chunks); first=True; cs=a0-0.05
    for j,c in enumerate(chunks):
        ce = a1+0.45 if j==len(chunks)-1 else cs+(a1-a0)*len(c)/tot
        n+=1; png=f'{T}/subs/sub{n:02d}.png'
        out=subprocess.run([T+'/textpng','sub',png,'\\n'.join(x.strip() for x in c.split('|'))],capture_output=True,text=True).stdout.strip()
        subs.append({'png':png,'from':round(cs,3),'to':round(min(ce,t+D-0.05),3),'fin':j==0,'fout':j==len(chunks)-1}); print(sid,j,out)
        cs=ce
    script.append((sid,title,a0,a1,t,t+D,sub,lines[sid][1]))
    t+=D
# end card
clips.append({'kind':'card','image':T+'/subs/endcard.png','dur':3.5})
total=t+3.5
# fix clip durations so frames sum exactly (compose uses cumulative)
json.dump({'out':T+'/video_only.mp4','fps':30,'clips':clips,'subs':subs,'xfade':0.3},open(T+'/spec.json','w'),ensure_ascii=False,indent=1)
json.dump({'total':total,'audio':audio},open(T+'/audio.json','w'))
def ts(x): return f'{int(x//60)}:{x%60:05.2f}'
with open(T+'/script.txt','w',encoding='utf-8') as f:
    f.write('טופי — סרטון הדרכה (עברית) — תסריט קריינות להקלטה\n')
    f.write(f'אורך כולל: {ts(total)}  |  {len(script)} שורות  |  הזמנים מתייחסים לסרטון tofy-tutorial-he-silent.mp4\n')
    f.write('לכל שורה: מתי להתחיל לדבר → מתי הקריינות הממוחשבת נגמרת, וכמה זמן יש עד סוף הסצנה (אפשר לדבר קצת יותר לאט, עד סוף החלון).\n')
    f.write('טיפ: הקליטו כל שורה כקובץ נפרד (line01.wav ...) והניחו אותו בדיוק בזמן ההתחלה.\n\n')
    for i,(sid,title,a0,a1,s0,s1,sub,spk) in enumerate(script,1):
        f.write(f'{i:02d}. [{ts(a0)} – {ts(a1)}]  (חלון מקסימלי עד {ts(s1)})  — {title}\n')
        f.write(f'    {sub}\n\n')
    f.write(f'[{ts(total-3.5)} – {ts(total)}]  כרטיס סיום: tofyapp.com (ללא קריינות)\n')
print('total',round(total,2),'clips',len(clips),'subs',len(subs))
for s in script: print(s[0], ts(s[4]), ts(s[5]), round(s[3]-s[2],2))
