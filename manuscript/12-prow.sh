# Links to gists for creating a serverless Jenkins X cluster
# gke-jx-serverless.sh: https://gist.github.com/a04269d359685bbd00a27643b5474ace
# eks-jx-serverless.sh: https://gist.github.com/69a4cbc65d8cb122d890add5997c463b
# aks-jx-serverless.sh: https://gist.github.com/a7cb7a28b7e84590fbb560b16a0ee98c
# install-serverless.sh: https://gist.github.com/f592c72486feb0fb1301778de08ba31d

GH_USER=[...]

jx delete application \
    $GH_USER/jx-serverless \
    -b

jx create quickstart \
  -l go \
  -p jx-prow \
  -b

cd jx-prow

jx get activities -f jx-prow -w

git checkout -b chat-ops

echo "ChatOps" | tee README.md

git add .

git commit -m "My first PR with prow"

git push --set-upstream origin chat-ops

jx create pr \
    -t "PR with prow" \
    --body "What I can say?" \
    -b

git checkout master

cat OWNERS

GH_USER=[...]

GH_APPROVER=[...]

echo "approvers:
- $GH_USER
- $GH_APPROVER
reviewers:
- $GH_USER
- $GH_APPROVER
" | tee OWNERS

git add .

git commit -m "Added an owner"

git push

open "https://github.com/$GH_USER/jx-prow/settings/collaboration"

git checkout master

git pull

git checkout -b my-pr

echo "My PR" | tee README.md

git add .

git commit -m "My second PR with prow"

git push --set-upstream origin my-pr

jx create pr \
    -t "My PR" \
    --body "What I can say?" \
    -b

kubectl -n cd describe cm plugins

cd ..

GH_USER=[...]

hub delete -y \
  $GH_USER/environment-tekton-staging

hub delete -y \
  $GH_USER/environment-tekton-production

hub delete -y $GH_USER/jx-prow

rm -rf jx-prow

rm -rf ~/.jx/environments/$GH_USER/environment-tekton-*
